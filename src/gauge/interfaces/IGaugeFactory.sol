// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

interface IGaugeFactory {
    /// @notice Thrown when a caller lacks permission to perform an action.
    error Forbidden();

    /// @notice Emitted when a gauge is created.
    /// @param pool The address of the bonded pool.
    /// @param rewardToken The reward token of the gauge.
    event GaugeCreated(address pool, address rewardToken);

    /// @notice Emitted when the voter is updated.
    /// @param voter The address of the updated voter.
    event VoterUpdated(address voter);

    /// @notice Returns the gauge implementation address.
    function implementation() external view returns (address);

    /// @notice Returns the voter address.
    function voter() external view returns (address);

    /// @notice Sets the voter.
    /// @param _voter The address of the voter.
    function setVoter(address _voter) external;

    /// @notice Creates a gauge.
    /// @param pool The address of the bonded pool.
    /// @param rewardToken The reward token of the gauge.
    /// @return instance The address of the newly created gauge.
    function createGauge(address pool, address rewardToken) external returns (address instance);
}
