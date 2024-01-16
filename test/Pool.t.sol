// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20, IERC20Metadata, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IPool, Pool, PoolFees} from "../src/pool/Pool.sol";
import {PoolFactory} from "../src/pool/PoolFactory.sol";

contract Token is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, type(uint256).max);
    }
}

contract PoolTest is Test {
    address token0;
    address token1;
    address stablePool;
    address volatilePool;
    uint256 protocolFee;

    function setUp() public {
        address tokenA = address(new Token("Midnight", "NIGHT"));
        address tokenB = address(new Token("veMidnight", "veNIGHT"));
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        PoolFactory factory = new PoolFactory(address(this));
        factory.setProtocolFeeHandler(address(this));

        stablePool = factory.createPool(token0, token1, true, 1);
        volatilePool = factory.createPool(token0, token1, false, 10);
    }

    function testMint(uint256 amount0, uint256 amount1, bool isStable) public returns (uint256 liquidity) {
        address pool = isStable ? stablePool : volatilePool;
        amount0 = bound(amount0, 1e16, 1e24);
        amount1 = bound(amount1, 1e16, 1e24);

        IERC20(token0).transfer(pool, amount0);
        IERC20(token1).transfer(pool, amount1);
        Pool(pool).mint(address(this));

        liquidity = Pool(pool).balanceOf(address(this));
        assertEq(liquidity, Math.sqrt(uint256(amount0) * amount1) - 10 ** 3);
    }

    function testMintInsufficientLiquidityMinted(bool isStable) public {
        address pool = isStable ? stablePool : volatilePool;
        testMint(0, 0, isStable);

        vm.expectRevert(IPool.InsufficientLiquidityMinted.selector);
        Pool(pool).mint(address(this));
    }

    function testBurn(uint256 amount0, uint256 amount1, bool isStable) public {
        address pool = isStable ? stablePool : volatilePool;
        amount0 = bound(amount0, 1e16, 1e24);
        amount1 = bound(amount1, 1e16, 1e24);

        uint256 liquidity = testMint(amount0, amount1, isStable);
        uint256 token0Locked = amount0 * 10 ** 3 / liquidity;
        uint256 token1Locked = amount1 * 10 ** 3 / liquidity;
        uint256 initialToken0Balance = IERC20(token0).balanceOf(address(this));
        uint256 initialToken1Balance = IERC20(token1).balanceOf(address(this));

        Pool(pool).transfer(pool, liquidity);
        Pool(pool).burn(address(this));

        uint256 token0Balance = IERC20(token0).balanceOf(address(this));
        uint256 token1Balance = IERC20(token1).balanceOf(address(this));

        assertApproxEqAbs(amount0 - token0Locked, token0Balance - initialToken0Balance, 1);
        assertApproxEqAbs(amount1 - token1Locked, token1Balance - initialToken1Balance, 1);
    }

    function testBurnInsufficientInputAmount(bool isStable) public {
        address pool = isStable ? stablePool : volatilePool;
        IERC20(token0).transfer(pool, 1000);
        IERC20(token1).transfer(pool, 1e24);
        Pool(pool).mint(address(this));
        Pool(pool).transfer(pool, 1);

        vm.expectRevert(IPool.InsufficientLiquidityBurned.selector);
        Pool(pool).burn(address(this));
    }

    function testSwap(uint256 amount0, uint256 amount1, uint256 amountIn, bool isStable, bool isZero) public {
        address pool = isStable ? stablePool : volatilePool;
        (address tokenToSend, address tokenToReceive) = isZero ? (token0, token1) : (token1, token0);
        amountIn = bound(amountIn, 1e16, 1e24);
        testMint(amount0, amount1, isStable);

        uint256 initialBalance = IERC20(tokenToReceive).balanceOf(address(this));
        uint256 amountOut = Pool(pool).getAmountOut(amountIn, tokenToSend);
        amountOut -= amountOut / 1e16 + 1;
        IERC20(tokenToSend).transfer(pool, amountIn);

        isZero
            ? Pool(pool).swap(0, amountOut, address(this), new bytes(0))
            : Pool(pool).swap(amountOut, 0, address(this), new bytes(0));

        uint256 balance = IERC20(tokenToReceive).balanceOf(address(this));
        assertEq(balance - initialBalance, amountOut);
    }

    function testSwapInsufficientOutputAmount(bool isStable) public {
        address pool = isStable ? stablePool : volatilePool;

        vm.expectRevert(IPool.InsufficientOutputAmount.selector);
        Pool(pool).swap(0, 0, address(this), new bytes(0));
    }

    function testSwapInsufficientLiquidity(bool isStable) public {
        address pool = isStable ? stablePool : volatilePool;

        vm.expectRevert(IPool.InsufficientLiquidity.selector);
        Pool(pool).swap(0, 1, address(this), new bytes(0));
    }

    function testSwapInvalidTo(uint256 amount0, uint256 amount1, bool isStable) public {
        address pool = isStable ? stablePool : volatilePool;
        testMint(amount0, amount1, isStable);

        vm.expectRevert(IPool.InvalidTo.selector);
        Pool(pool).swap(0, 1, token0, new bytes(0));
    }

    function testSwapK(uint256 amount0, uint256 amount1, uint256 amountIn, bool isStable, bool isZero) public {
        address pool = isStable ? stablePool : volatilePool;
        address tokenToSend = isZero ? token0 : token1;
        amountIn = bound(amountIn, 1e16, 1e24);
        testMint(amount0, amount1, isStable);

        uint256 amountOut = Pool(pool).getAmountOut(amountIn, tokenToSend);
        IERC20(tokenToSend).transfer(pool, 1);

        vm.expectRevert(IPool.K.selector);
        isZero
            ? Pool(pool).swap(0, amountOut, address(this), new bytes(0))
            : Pool(pool).swap(amountOut, 0, address(this), new bytes(0));
    }

    function testSwapInsufficientInputAmount(bool isStable) public {
        address pool = isStable ? stablePool : volatilePool;
        testSync(2, 2, isStable);

        vm.expectRevert(IPool.InsufficientInputAmount.selector);
        Pool(pool).swap(0, 1, address(this), new bytes(0));
    }

    function testSkim(uint256 amount0, uint256 amount1, bool isStable) public {
        address pool = isStable ? stablePool : volatilePool;
        IERC20(token0).transfer(pool, amount0);
        IERC20(token1).transfer(pool, amount1);
        Pool(pool).skim(address(this));

        assertEq(IERC20(token0).balanceOf(address(this)), type(uint256).max);
        assertEq(IERC20(token1).balanceOf(address(this)), type(uint256).max);
    }

    function testSync(uint256 amount0, uint256 amount1, bool isStable) public {
        address pool = isStable ? stablePool : volatilePool;
        IERC20(token0).transfer(pool, amount0);
        IERC20(token1).transfer(pool, amount1);
        Pool(pool).sync();

        assertEq(Pool(pool).reserve0(), amount0);
        assertEq(Pool(pool).reserve1(), amount1);
    }

    function testAccrueFees(uint256 amount0, uint256 amount1, uint256 amountIn, bool isStable, bool isZero)
        public
        returns (uint256 fees)
    {
        address pool = isStable ? stablePool : volatilePool;
        amountIn = bound(amountIn, 1e16, 1e24);
        testSwap(amount0, amount1, amountIn, isStable, isZero);

        fees = amountIn * Pool(pool).feeTier() / 10000;
        uint256 feesAfterProtocolFee = fees - fees * 12 / 100;
        uint256 ratio = feesAfterProtocolFee * 1e18 / Pool(pool).totalSupply();
        assertEq(isZero ? Pool(pool).index0() : Pool(pool).index1(), ratio);
    }

    function testWithdrawFees(uint256 amount0, uint256 amount1, uint256 amountIn, bool isStable, bool isZero) public {
        address pool = isStable ? stablePool : volatilePool;
        address token = isZero ? token0 : token1;
        testAccrueFees(amount0, amount1, amountIn, isStable, isZero);

        uint256 index = isZero ? Pool(pool).index0() : Pool(pool).index1();
        uint256 initialBalance = IERC20(token).balanceOf(address(this));
        Pool(pool).claim();

        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 fees = Pool(pool).balanceOf(address(this)) * index / 1e18;
        assertEq(balance - initialBalance, fees);
    }

    function testProtocolFees(uint256 amount0, uint256 amount1, uint256 amountIn, bool isStable, bool isZero)
        public
        returns (uint256 protocolFees)
    {
        address pool = isStable ? stablePool : volatilePool;
        uint256 fees = testAccrueFees(amount0, amount1, amountIn, isStable, isZero);
        address poolFees = Pool(pool).fees();

        protocolFees = isZero ? PoolFees(poolFees).protocolFees0() : PoolFees(poolFees).protocolFees1();
        assertEq(protocolFees, fees * 12 / 100);
    }

    function testWithdrawProtocolFees(uint256 amount0, uint256 amount1, uint256 amountIn, bool isStable, bool isZero)
        public
    {
        address pool = isStable ? stablePool : volatilePool;
        address token = isZero ? token0 : token1;
        uint256 protocolFees = testProtocolFees(amount0, amount1, amountIn, isStable, isZero);
        uint256 initialBalance = IERC20(token).balanceOf(address(this));
        address poolFees = Pool(pool).fees();
        
        isZero
            ? PoolFees(poolFees).withdrawProtocolFees(address(this), protocolFees, 0)
            : PoolFees(poolFees).withdrawProtocolFees(address(this), 0, protocolFees);

        uint256 balance = IERC20(token).balanceOf(address(this));
        assertEq(balance - initialBalance, protocolFees);
    }
}
