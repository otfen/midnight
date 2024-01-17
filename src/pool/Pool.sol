// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC20, ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IPool} from "./interfaces/IPool.sol";
import {IPoolCallee} from "./interfaces/IPoolCallee.sol";
import {IPoolFactory} from "./interfaces/IPoolFactory.sol";
import {PoolFees} from "./PoolFees.sol";

contract Pool is ERC20, ERC20Permit, ReentrancyGuard, Initializable, IPool {
    using SafeERC20 for IERC20;

    uint256 internal constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 internal constant MINIMUM_STABLE_K = 10 ** 10;

    address public token0;
    address public token1;
    uint256 internal decimals0;
    uint256 internal decimals1;
    bool public stable;
    uint256 public feeTier;
    address public fees;
    address public factory;

    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public blockTimestampLast;
    uint256 public reserve0CumulativeLast;
    uint256 public reserve1CumulativeLast;

    uint256 public constant periodSize = 30 minutes;
    Observation[] public observations;

    uint256 public index0;
    uint256 public index1;

    mapping(address => uint256) public supplyIndex0;
    mapping(address => uint256) public supplyIndex1;
    mapping(address => uint256) public claimable0;
    mapping(address => uint256) public claimable1;

    constructor() ERC20("Midnight Automated Market Maker", "NIGHT") ERC20Permit("Midnight Automated Market Maker") {}

    function initialize(address _token0, address _token1, bool _stable, uint256 _feeTier) external initializer {
        (token0, token1, stable, feeTier) = (_token0, _token1, _stable, _feeTier);

        factory = msg.sender;
        fees = address(new PoolFees(_token0, _token1, factory));
        decimals0 = 10 ** IERC20Metadata(_token0).decimals();
        decimals1 = 10 ** IERC20Metadata(_token1).decimals();

        observations.push(Observation(block.timestamp, 0, 0));
    }

    function name() public view override returns (string memory) {
        return string(
            abi.encodePacked(
                IERC20Metadata(token0).symbol(),
                "/",
                IERC20Metadata(token1).symbol(),
                stable ? " Stable Automated Market Maker" : " Volatile Automated Market Maker"
            )
        );
    }

    function symbol() public view override returns (string memory) {
        return string(
            abi.encodePacked(
                stable ? "s" : "v", "AMM-", IERC20Metadata(token0).symbol(), "/", IERC20Metadata(token1).symbol()
            )
        );
    }

    function metadata()
        external
        view
        returns (address t0, address t1, uint256 d0, uint256 d1, uint256 r0, uint256 r1, bool s, uint256 ft)
    {
        return (token0, token1, decimals0, decimals1, reserve0, reserve1, stable, feeTier);
    }

    function getReserves() public view returns (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256) {
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        amountIn -= amountIn * feeTier / 10000;
        return _getAmountOut(amountIn, tokenIn, _reserve0, _reserve1);
    }

    function currentCumulativePrices()
        public
        view
        returns (uint256 reserve0Cumulative, uint256 reserve1Cumulative, uint256 blockTimestamp)
    {
        blockTimestamp = block.timestamp;
        reserve0Cumulative = reserve0CumulativeLast;
        reserve1Cumulative = reserve1CumulativeLast;

        (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast) = getReserves();
        if (_blockTimestampLast != blockTimestamp) {
            uint256 timeElapsed = blockTimestamp - _blockTimestampLast;
            reserve0Cumulative += _reserve0 * timeElapsed;
            reserve1Cumulative += _reserve1 * timeElapsed;
        }
    }

    function observationLength() external view returns (uint256) {
        return observations.length;
    }

    function lastObservation() public view returns (Observation memory) {
        return observations[observations.length - 1];
    }

    function current(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut) {
        Observation memory _observation = lastObservation();
        (uint256 reserve0Cumulative, uint256 reserve1Cumulative,) = currentCumulativePrices();
        if (block.timestamp == _observation.timestamp) {
            _observation = observations[observations.length - 2];
        }

        uint256 timeElapsed = block.timestamp - _observation.timestamp;
        uint256 _reserve0 = (reserve0Cumulative - _observation.reserve0Cumulative) / timeElapsed;
        uint256 _reserve1 = (reserve1Cumulative - _observation.reserve1Cumulative) / timeElapsed;
        amountOut = _getAmountOut(amountIn, tokenIn, _reserve0, _reserve1);
    }

    function quote(address tokenIn, uint256 amountIn, uint256 granularity) external view returns (uint256 amountOut) {
        uint256[] memory _prices = sample(tokenIn, amountIn, granularity, 1);
        uint256 priceAverageCumulative;
        for (uint256 i = 0; i < _prices.length; i++) {
            priceAverageCumulative += _prices[i];
        }
        return priceAverageCumulative / granularity;
    }

    function prices(address tokenIn, uint256 amountIn, uint256 points) external view returns (uint256[] memory) {
        return sample(tokenIn, amountIn, points, 1);
    }

    function sample(address tokenIn, uint256 amountIn, uint256 points, uint256 window)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory _prices = new uint256[](points);
        uint256 length = observations.length - 1;
        uint256 i = length - (points * window);
        uint256 nextIndex = 0;
        uint256 index = 0;

        for (; i < length; i += window) {
            nextIndex = i + window;
            uint256 timeElapsed = observations[nextIndex].timestamp - observations[i].timestamp;
            uint256 _reserve0 =
                (observations[nextIndex].reserve0Cumulative - observations[i].reserve0Cumulative) / timeElapsed;
            uint256 _reserve1 =
                (observations[nextIndex].reserve1Cumulative - observations[i].reserve1Cumulative) / timeElapsed;
            _prices[index] = _getAmountOut(amountIn, tokenIn, _reserve0, _reserve1);
            unchecked {
                ++index;
            }
        }
        return _prices;
    }

    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        uint256 _balance0 = IERC20(token0).balanceOf(address(this));
        uint256 _balance1 = IERC20(token1).balanceOf(address(this));
        uint256 _amount0 = _balance0 - _reserve0;
        uint256 _amount1 = _balance1 - _reserve1;
        uint256 _totalSupply = totalSupply();

        if (_totalSupply == 0) {
            if (stable && _k(_amount0, _amount1) < MINIMUM_STABLE_K) revert InsufficientK();
            liquidity = Math.sqrt(_amount0 * _amount1) - MINIMUM_LIQUIDITY;
            _mint(address(1), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(_amount0 * _totalSupply / _reserve0, _amount1 * _totalSupply / _reserve1);
        }

        if (liquidity == 0) revert InsufficientLiquidityMinted();
        _mint(to, liquidity);

        _updateReserves(_balance0, _balance1, _reserve0, _reserve1);
        emit Mint(_amount0, _amount1);
    }

    function burn(address to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        (address _token0, address _token1) = (token0, token1);
        uint256 _balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 _balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 _liquidity = balanceOf(address(this));
        uint256 _totalSupply = totalSupply();

        amount0 = _liquidity * _balance0 / _totalSupply;
        amount1 = _liquidity * _balance1 / _totalSupply;
        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidityBurned();
        _burn(address(this), _liquidity);

        IERC20(_token0).safeTransfer(to, amount0);
        IERC20(_token1).safeTransfer(to, amount1);
        _balance0 = IERC20(_token0).balanceOf(address(this));
        _balance1 = IERC20(_token1).balanceOf(address(this));

        _updateReserves(_balance0, _balance1, _reserve0, _reserve1);
        emit Burn(amount0, amount1, to);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external nonReentrant {
        if (amount0Out == 0 && amount1Out == 0) revert InsufficientOutputAmount();
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        if (amount0Out >= _reserve0 || amount1Out >= _reserve1) revert InsufficientLiquidity();

        uint256 _balance0;
        uint256 _balance1;
        {
            (address _token0, address _token1) = (token0, token1);
            if (to == token0 || to == token1) revert InvalidTo();
            if (amount0Out > 0) IERC20(_token0).safeTransfer(to, amount0Out);
            if (amount1Out > 0) IERC20(_token1).safeTransfer(to, amount1Out);
            if (data.length > 0) IPoolCallee(to).hook(msg.sender, amount0Out, amount1Out, data);
            _balance0 = IERC20(_token0).balanceOf(address(this));
            _balance1 = IERC20(_token1).balanceOf(address(this));
        }

        uint256 amount0In = _balance0 > _reserve0 - amount0Out ? _balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = _balance1 > _reserve1 - amount1Out ? _balance1 - (_reserve1 - amount1Out) : 0;
        if (amount0In == 0 && amount1In == 0) revert InsufficientInputAmount();
        {
            (address _token0, address _token1) = (token0, token1);
            if (amount0In > 0) _update0(amount0In * feeTier / 10000);
            if (amount1In > 0) _update1(amount1In * feeTier / 10000);
            _balance0 = IERC20(_token0).balanceOf(address(this));
            _balance1 = IERC20(_token1).balanceOf(address(this));
            if (_k(_balance0, _balance1) < _k(_reserve0, _reserve1)) revert K();
        }

        _updateReserves(_balance0, _balance1, _reserve0, _reserve1);
        emit Swap(amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function skim(address to) external nonReentrant {
        (address _token0, address _token1) = (token0, token1);
        IERC20(_token0).safeTransfer(to, IERC20(_token0).balanceOf(address(this)) - reserve0);
        IERC20(_token1).safeTransfer(to, IERC20(_token1).balanceOf(address(this)) - reserve1);
    }

    function sync() external nonReentrant {
        _updateReserves(
            IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1
        );
    }

    function claim() external returns (uint256 claimed0, uint256 claimed1) {
        _updateFees(msg.sender);

        claimed0 = claimable0[msg.sender];
        claimed1 = claimable1[msg.sender];

        if (claimed0 > 0 || claimed1 > 0) {
            claimable0[msg.sender] = 0;
            claimable1[msg.sender] = 0;

            PoolFees(fees).claimFeesFor(msg.sender, claimed0, claimed1);
            emit Claim(claimed0, claimed1);
        }
    }

    function _f(uint256 x0, uint256 y) internal pure returns (uint256) {
        return x0 * (y * y / 1e18 * y / 1e18) / 1e18 + (x0 * x0 / 1e18 * x0 / 1e18) * y / 1e18;
    }

    function _d(uint256 x0, uint256 y) internal pure returns (uint256) {
        return 3 * x0 * (y * y / 1e18) / 1e18 + (x0 * x0 / 1e18 * x0 / 1e18);
    }

    function _get_y(uint256 x0, uint256 xy, uint256 y) internal pure returns (uint256) {
        for (uint256 i = 0; i < 255; i++) {
            uint256 y_prev = y;
            uint256 k = _f(x0, y);
            if (k < xy) {
                uint256 dy = (xy - k) * 1e18 / _d(x0, y);
                y = y + dy;
            } else {
                uint256 dy = (k - xy) * 1e18 / _d(x0, y);
                y = y - dy;
            }
            if (y > y_prev) {
                if (y - y_prev <= 1) {
                    return y;
                }
            } else {
                if (y_prev - y <= 1) {
                    return y;
                }
            }
        }
        return y;
    }

    function _k(uint256 x, uint256 y) internal view returns (uint256) {
        if (stable) {
            uint256 _x = x * 1e18 / decimals0;
            uint256 _y = y * 1e18 / decimals1;
            uint256 _a = (_x * _y) / 1e18;
            uint256 _b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);
            return _a * _b / 1e18;
        } else {
            return x * y;
        }
    }

    function _getAmountOut(uint256 amountIn, address tokenIn, uint256 _reserve0, uint256 _reserve1)
        internal
        view
        returns (uint256)
    {
        if (stable) {
            uint256 xy = _k(_reserve0, _reserve1);
            _reserve0 = _reserve0 * 1e18 / decimals0;
            _reserve1 = _reserve1 * 1e18 / decimals1;
            (uint256 reserveA, uint256 reserveB) = tokenIn == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
            amountIn = tokenIn == token0 ? amountIn * 1e18 / decimals0 : amountIn * 1e18 / decimals1;
            uint256 y = reserveB - _get_y(amountIn + reserveA, xy, reserveB);
            return y * (tokenIn == token0 ? decimals1 : decimals0) / 1e18;
        } else {
            (uint256 reserveA, uint256 reserveB) = tokenIn == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
            return amountIn * reserveB / (reserveA + amountIn);
        }
    }

    function _updateReserves(uint256 balance0, uint256 balance1, uint256 _reserve0, uint256 _reserve1) internal {
        uint256 blockTimestamp = block.timestamp;
        uint256 timeElapsed = blockTimestamp - blockTimestampLast;
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            reserve0CumulativeLast += _reserve0 * timeElapsed;
            reserve1CumulativeLast += _reserve1 * timeElapsed;
        }

        Observation memory _point = lastObservation();
        timeElapsed = blockTimestamp - _point.timestamp;
        if (timeElapsed > periodSize) {
            observations.push(Observation(blockTimestamp, reserve0CumulativeLast, reserve1CumulativeLast));
        }

        reserve0 = balance0;
        reserve1 = balance1;
        blockTimestampLast = blockTimestamp;

        emit Sync(reserve0, reserve1);
    }

    function _updateFees(address recipient) internal {
        uint256 _supplied = balanceOf(recipient);
        if (_supplied == 0) {
            supplyIndex0[recipient] = index0;
            supplyIndex1[recipient] = index1;
            return;
        }

        uint256 _supplyIndex0 = supplyIndex0[recipient];
        uint256 _supplyIndex1 = supplyIndex1[recipient];
        uint256 _index0 = index0;
        uint256 _index1 = index1;
        uint256 _delta0 = _index0 - _supplyIndex0;
        uint256 _delta1 = _index1 - _supplyIndex1;

        supplyIndex0[recipient] = _index0;
        supplyIndex1[recipient] = _index1;

        if (_delta0 > 0) {
            uint256 _share = _supplied * _delta0 / 1e18;
            claimable0[recipient] += _share;
        }

        if (_delta1 > 0) {
            uint256 _share = _supplied * _delta1 / 1e18;
            claimable1[recipient] += _share;
        }
    }

    function _update0(uint256 amount) internal {
        uint256 protocolFee = amount * IPoolFactory(factory).protocolFee() / 10000;
        PoolFees(fees).notifyProtocolFee(protocolFee, 0);
        IERC20(token0).safeTransfer(fees, amount);

        uint256 ratio = (amount - protocolFee) * 1e18 / totalSupply();
        if (ratio > 0) index0 += ratio;

        emit Fees(amount, 0);
    }

    function _update1(uint256 amount) internal {
        uint256 protocolFee = amount * IPoolFactory(factory).protocolFee() / 10000;
        PoolFees(fees).notifyProtocolFee(0, protocolFee);
        IERC20(token1).safeTransfer(fees, amount);

        uint256 ratio = (amount - protocolFee) * 1e18 / totalSupply();
        if (ratio > 0) index1 += ratio;

        emit Fees(0, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        _updateFees(from);
        _updateFees(to);
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, IERC20Permit) returns (uint256) {
        return super.nonces(owner);
    }
}
