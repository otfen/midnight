// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

interface IPoolFactory {
    /// @notice Thrown when the fee set by governance exceeds the hardcoded limit.
    error InvalidFee();

    /// @notice Thrown during pool creation when both tokens are identical.
    error IdenticalAddress();

    /// @notice Thrown during pool creation when a token is the zero address.
    error ZeroAddress();

    /// @notice Thrown during pool creation when the pool already exists.
    error PoolExists();

    /// @notice Thrown during pool creation when the fee tier specified has not been approved by governance.
    error UnapprovedFeeTier();

    /// @notice Emitted when a fee tier is updated.
    /// @param feeTier The fee tier.
    /// @param approved Whether the fee tier has been approved or discontinued.
    event FeeTierUpdate(uint256 feeTier, bool approved);

    /// @notice Emitted when the protocol fee is updated.
    /// @param protocolFee The new protocol fee.
    event ProtocolFeeUpdate(uint256 protocolFee);

    /// @notice Emitted when the protocol fee handler is updated.
    /// @param protocolFeeHandler The new protocol fee handler.
    event ProtocolFeeHandlerUpdate(address protocolFeeHandler);

    /// @notice Emitted when a pool is created.
    /// @param token0 The first pooled token.
    /// @param token1 The second pooled token.
    /// @param stable If the pool is stable.
    /// @param feeTier The fee tier of the pool.
    /// @param pool The newly created pool's address.
    /// @param poolsLength The new length of the pools array.
    event PoolCreated(
        address indexed token0, address indexed token1, bool stable, uint256 feeTier, address pool, uint256 poolsLength
    );

    /// @notice Returns the pool implementation address.
    function implementation() external view returns (address);

    /// @notice Returns the protocol fee.
    function protocolFee() external view returns (uint256);

    /// @notice Returns the protocol fee handler.
    function protocolFeeHandler() external view returns (address);

    /// @notice Returns whether a fee tier is approved.
    /// @param feeTier The fee tier to check.
    function isFeeTierApproved(uint256 feeTier) external view returns (bool);

    /// @notice Returns the address of a created pool.
    /// @param token0 The first pooled token.
    /// @param token1 The second pooled token.
    /// @param stable If the pool is stable.
    /// @param feeTier The fee tier of the pool.
    function getPool(address token0, address token1, bool stable, uint256 feeTier) external view returns (address);

    /// @notice Returns the number of created pools.
    function poolsLength() external view returns (uint256);

    /// @notice Approves or discontinues a fee tier.
    function setFeeTier(uint256 feeTier, bool approved) external;

    /// @notice Sets the protocol fee.
    /// @param _protocolFee The new protocol fee.
    function setProtocolFee(uint256 _protocolFee) external;

    /// @notice Sets the protocol fee handler.
    /// @param _protocolFeeHandler The protocol fee handler.
    function setProtocolFeeHandler(address _protocolFeeHandler) external;

    /// @notice Creates a pool.
    /// @param tokenA The first pooled token.
    /// @param tokenB The second pooled token.
    /// @param stable If the pool is stable.
    /// @param feeTier The fee tier of the pool.
    /// @return pool The newly created pool's address.
    function createPool(address tokenA, address tokenB, bool stable, uint256 feeTier) external returns (address pool);
}
