// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

interface IPoolFees {
    /// @notice Thrown when a caller lacks permission to perform an action.
    error Forbidden();

    /// @notice Emitted when protocol fees are withdrawn.
    /// @param recipient The recipient of the protocol fees.
    /// @param amount0 The withdrawal amount of the first pooled token.
    /// @param amount1 The withdrawal amount of the second pooled token.
    event Withdrawal(address indexed recipient, uint256 amount0, uint256 amount1);

    /// @notice Returns the address of the bonded pool.
    function pool() external returns (address);

    /// @notice Returns the address of the first pooled token.
    function token0() external returns (address);

    /// @notice Returns the address of the second pooled token.
    function token1() external returns (address);

    /// @notice Returns the amount of unclaimed protocol fees of the first pooled token.
    function protocolFees0() external returns (uint256);

    /// @notice Returns the amount of unclaimed protocol fees of the second pooled token.
    function protocolFees1() external returns (uint256);

    /// @notice Claims fees for a specified recipient.
    /// @param recipient The recipient of the fees.
    /// @param amount0 The amount of the first pooled token claimed.
    /// @param amount1 The amount of the second pooled token claimed.
    function claimFeesFor(address recipient, uint256 amount0, uint256 amount1) external;

    /// @notice Notifies the contract of incoming protocol fees.
    /// @param amount0 The incoming amount of the first pooled token.
    /// @param amount1 The incoming amount of the second pooled token.
    function notifyProtocolFee(uint256 amount0, uint256 amount1) external;

    /// @notice Withdraws protocol fees from the contract.
    /// @param recipient The recipient of the protocol fees.
    /// @param amount0 The withdrawal amount of the first pooled token.
    /// @param amount1 The withdrawal amount of the second pooled token.
    function withdrawProtocolFees(address recipient, uint256 amount0, uint256 amount1) external;
}
