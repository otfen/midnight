// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

interface IPool is IERC20, IERC20Permit {
    /// @notice Thrown when the amount out exceeds the pool's reserves.
    error InsufficientLiquidity();

    /// @notice Thrown when the amount of liquidity minted is equal to zero.
    error InsufficientLiquidityMinted();

    /// @notice Thrown when the amount of either token redeemed by burning liquidity is equal to zero.
    error InsufficientLiquidityBurned();

    /// @notice Thrown when both input amounts are equal to zero.
    error InsufficientInputAmount();

    /// @notice Thrown when both output amounts are equal to zero.
    error InsufficientOutputAmount();

    /// @notice Thrown when x³y + y³x is less than the MINIMUM_STABLE_K constant during the initial mint.
    error InsufficientK();

    /// @notice Thrown when the recipient of a swap is a pooled token.
    error InvalidTo();

    /// @notice Thrown when x * y < k or x³y + y³x < k.
    error K();

    /// @notice Emitted when fees are accrued.
    /// @param amount0 The accrual amount of the first pooled token.
    /// @param amount1 The accrual amount of the second pooled token.
    event Fees(uint256 amount0, uint256 amount1);

    /// @notice Emitted when liquidity is minted.
    /// @param amount0 The amount of the first pooled token used to mint liquidity.
    /// @param amount1 The amount of the second pooled token used to mint liquidity.
    event Mint(uint256 amount0, uint256 amount1);

    /// @notice Emitted when liquidity is burned.
    /// @param amount0 The amount of the first pooled token sent.
    /// @param amount1 The amount of the second pooled token sent.
    /// @param to The address where the pooled tokens are sent to.
    event Burn(uint256 amount0, uint256 amount1, address indexed to);

    /// @notice Emitted when a swap is completed.
    /// @param amount0In The amount of the first pooled token received.
    /// @param amount1In The amount of the second pooled token received.
    /// @param amount0Out The amount of the first pooled token sent.
    /// @param amount1Out The amount of the second pooled token sent.
    /// @param to The address where the pooled tokens are sent to.
    event Swap(uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out, address indexed to);

    /// @notice Emitted when the reserves are updated.
    /// @param reserve0 The new reserve balance of the first pooled token.
    /// @param reserve1 The new reserve balance of the second pooled token.
    event Sync(uint256 reserve0, uint256 reserve1);

    /// @notice Emitted when fees are claimed.
    /// @param amount0 The amount of the first pooled token claimed.
    /// @param amount1 The amount of the second pooled token claimed.
    event Claim(uint256 amount0, uint256 amount1);

    /// @notice A structure to capture time period observations, used for local oracles.
    /// @param timestamp The timestamp of the observation.
    /// @param reserve0Cumulative The cumulative reserve balance of the first pooled token.
    /// @param reserve1Cumulative The cumulative reserve balance of the second pooled token.
    struct Observation {
        uint256 timestamp;
        uint256 reserve0Cumulative;
        uint256 reserve1Cumulative;
    }

    /// @notice Returns the address of the first pooled token.
    function token0() external view returns (address);

    /// @notice Returns the address of the second pooled token.
    function token1() external view returns (address);

    /// @notice Returns a boolean indicating if the pool is stable.
    function stable() external view returns (bool);

    /// @notice Returns the pool's fee tier.
    function feeTier() external view returns (uint256);

    /// @notice Returns the address of the fees contract.
    function fees() external view returns (address);

    /// @notice Returns the address of the factory contract.
    function factory() external view returns (address);

    /// @notice Returns the reserve balance of the first pooled token.
    function reserve0() external view returns (uint256);

    /// @notice Returns the reserve balance of the second pooled token.
    function reserve1() external view returns (uint256);

    /// @notice Returns the last updated timestamp of the reserve balances.
    function blockTimestampLast() external view returns (uint256);

    /// @notice Returns the last cumulative reserve balance of the first pooled token.
    function reserve0CumulativeLast() external view returns (uint256);

    /// @notice Returns the last cumulative reserve balance of the second pooled token.
    function reserve1CumulativeLast() external view returns (uint256);

    /// @notice Returns the observation period size.
    function periodSize() external view returns (uint256);

    /// @notice Returns the global fee index of the first pooled token.
    function index0() external view returns (uint256);

    /// @notice Returns the global fee index of the second pooled token.
    function index1() external view returns (uint256);

    /// @notice Returns the supply index of the first pooled token for a specified user.
    function supplyIndex0(address) external view returns (uint256);

    /// @notice Returns the supply index of the second pooled token for a specified user.
    function supplyIndex1(address) external view returns (uint256);

    /// @notice Returns the claimable fees of the first pooled token for a specified user.
    function claimable0(address) external view returns (uint256);

    /// @notice Returns the claimable fees of the second pooled token for a specified user.
    function claimable1(address) external view returns (uint256);

    /// @notice Initializes the pool. Called by the pool factory after pool creation.
    /// @param _token0 The address of the first pooled token.
    /// @param _token1 The address of the second pooled token.
    /// @param _stable If the pool is stable.
    /// @param _feeTier The fee tier of the pool.
    function initialize(address _token0, address _token1, bool _stable, uint256 _feeTier) external;

    /// @notice Returns pool metadata.
    /// @return t0 The address of first pooled token.
    /// @return t1 The address of second pooled token.
    /// @return d0 The number of units per token for the first pooled token.
    /// @return d1 The number of units per token for the second pooled token.
    /// @return r0 The reserve balance of the first pooled token.
    /// @return r1 The reserve balance of the second pooled token.
    /// @return s If the pool is stable.
    /// @return ft The fee tier of the pool.
    function metadata()
        external
        view
        returns (address t0, address t1, uint256 d0, uint256 d1, uint256 r0, uint256 r1, bool s, uint256 ft);

    /// @notice Returns the balances of the reserves.
    /// @return reserve0 The reserve balance of the first pooled token.
    /// @return reserve1 The reserve balance of the second pooled token.
    /// @return blockTimestampLast The timestamp of the last reserves update.
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1, uint256 blockTimestampLast);

    /// @notice Returns the amount out from a swap given the token in and amount in.
    /// @param amountIn The amount of the input token.
    /// @param tokenIn The address of the input token.
    /// @return amountOut The output amount of the counterpart pooled token.
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256 amountOut);

    /// @notice Returns the current cumulative prices using counterfactuals.
    /// @return reserve0Cumulative The cumulative price of first pooled token.
    /// @return reserve1Cumulative The cumulative price of second pooled token.
    /// @return blockTimestamp The current block timestamp.
    function currentCumulativePrices()
        external
        view
        returns (uint256 reserve0Cumulative, uint256 reserve1Cumulative, uint256 blockTimestamp);

    /// @notice Returns the number of observations captured.
    function observationLength() external view returns (uint256);

    /// @notice Returns the last observation.
    function lastObservation() external view returns (Observation memory);

    /// @notice Returns the current time-weighted average price given the token in and amount in.
    /// @param tokenIn The address of the input token.
    /// @param amountIn The amount of the input token.
    /// @return amountOut The output amount of the counterpart pooled token.
    function current(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut);

    /// @notice As per current, however, it allows for user-configured granularity up to the full window size.
    /// @param tokenIn The address of the input token.
    /// @param amountIn The input amount of the token.
    /// @param granularity The granularity.
    /// @return amountOut The output amount of the counterpart pooled token.
    function quote(address tokenIn, uint256 amountIn, uint256 granularity) external view returns (uint256 amountOut);

    /// @notice Returns a memory set of time-weighted average prices.
    /// @param tokenIn The address of the input token.
    /// @param amountIn The input amount of the token.
    /// @param points The number of price points.
    function prices(address tokenIn, uint256 amountIn, uint256 points) external view returns (uint256[] memory);

    /// @notice Returns a memory set of time-weighted average prices with a window argument.
    /// @param tokenIn The address of the input token.
    /// @param amountIn The input amount of the token.
    /// @param points The number of price points.
    /// @param window The number of observations to skip for each price point.
    function sample(address tokenIn, uint256 amountIn, uint256 points, uint256 window)
        external
        view
        returns (uint256[] memory);

    /// @notice Mints liquidity tokens.
    /// @dev This low-level function should be called from a contract that performs important safety checks.
    /// @param to The address where the minted liquidity tokens should be sent to.
    /// @return liquidity The amount of minted liquidity tokens.
    function mint(address to) external returns (uint256 liquidity);

    /// @notice Burns liquidity tokens.
    /// @dev This low-level function should be called from a contract that performs important safety checks.
    /// @param to The address where the redeemed pooled tokens should be sent to.
    /// @return amount0 The amount of the first pooled token sent.
    /// @return amount1 The amount of the second pooled token sent.
    function burn(address to) external returns (uint256 amount0, uint256 amount1);

    /// @notice Swaps a pooled token for another.
    /// @dev This low-level function should be called from a contract that performs important safety checks.
    /// @param amount0Out The desired output amount of the first pooled token.
    /// @param amount1Out The desired output amount of the second pooled token.
    /// @param to The address where the swapped tokens should be sent.
    /// @param data The data provided to flash swaps.
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    /// @notice Forces balances to match reserves.
    /// @param to The address where excess balances should be sent.
    function skim(address to) external;

    /// @notice Forces reserves to match balances.
    function sync() external;

    /// @notice Claims accumulated fees.
    /// @return claimed0 The amount of fees claimed of the first pooled token.
    /// @return claimed1 The amount of fees claimed of the second pooled token.
    function claim() external returns (uint256 claimed0, uint256 claimed1);
}
