// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

interface IVoter {
    /// @notice Thrown when the emissions rate set by governance exceeds the hardcoded limit.
    error InvalidRate();

    /// @notice Thrown when an address is not a votable gauge.
    error InvalidGauge();

    /// @notice Thrown when the total vote weight exceeds the voter's available vote weight.
    error InvalidWeight();

    /// @notice Thrown when an action requiring a new epoch is called prematurely.
    error NotNewEpoch();

    /// @notice Thrown when a duplicate vote is submitted.
    error DuplicateVote();

    /// @notice Emitted when the epoch's emissions are updated.
    /// @param epochEmissionsBps The new inflation rate per epoch.
    event EpochEmissionsUpdated(uint256 epochEmissionsBps);

    /// @notice Emitted when a gauge is added to the votable gauges.
    /// @param gauge The added gauge.
    event GaugeAdded(address gauge);

    /// @notice Emitted when a gauge is removed from the votable gauges.
    /// @param gauge The removed gauge.
    event GaugeRemoved(address gauge);

    /// @notice Emitted when an epoch has elapsed.
    /// @param epoch The new epoch.
    event NewEpoch(uint256 epoch);

    /// @notice Emitted when an account's votes have been resetted.
    event Reset();

    /// @notice Emitted when an account votes.
    /// @param votedGauges A list of the voted gauges.
    /// @param weights A list of the corresponding weights.
    event Vote(address[] votedGauges, uint256[] weights);

    /// @notice Returns the address of emissions token.
    function midnight() external returns (address);

    /// @notice Returns the address of the vote escrowed token.
    function veMidnight() external returns (address);

    /// @notice Returns the current epoch.
    function epoch() external returns (uint256);

    /// @notice Returns the epoch inflation rate.
    function epochEmissionsBps() external returns (uint256);

    /// @notice Returns the total weight of the current epoch.
    function epochTotalWeight() external returns (uint256);

    /// @notice Returns the weight of a gauge.
    /// @dev The weight of the gauge decreases as voting incentives are claimed.
    /// @param epoch The voting epoch.
    /// @param gauge The gauge.
    function gaugeWeight(uint256 epoch, address gauge) external returns (uint256);

    /// @notice Sets the epoch inflation rate.
    /// @param _epochEmissionsBps The new inflation rate per epoch.
    function setEpochEmissionsBps(uint256 _epochEmissionsBps) external;

    /// @notice Returns all votable gauges.
    function gauges() external view returns (address[] memory);

    /// @notice Returns whether an address is a votable gauge.
    /// @param gauge The address to check.
    function isGauge(address gauge) external view returns (bool);

    /// @notice Adds a gauge to the votable gauges.
    /// @param gauge The gauge to add.
    function addGauge(address gauge) external;

    /// @notice Removes a gauge from the votable gauges.
    /// @param gauge The gauge to remove.
    function removeGauge(address gauge) external;

    /// @notice Returns the votes of an account.
    /// @dev Votes are removed as voting incentives are claimed.
    /// @param votingEpoch The voting epoch.
    /// @param account The voter.
    function votes(uint256 votingEpoch, address account) external view returns (address[] memory);

    /// @notice Returns whether an account has voted.
    /// @param votingEpoch The voting epoch.
    /// @param account The voter.
    function voted(uint256 votingEpoch, address account) external view returns (bool);

    /// @notice Returns the weight of a vote.
    /// @param votingEpoch The voting epoch.
    /// @param account The voter.
    /// @param gauge The voted gauge.
    function voteWeight(uint256 votingEpoch, address account, address gauge) external view returns (uint256);

    /// @notice Resets the votes of the caller.
    function reset() external;

    /// @notice Distributes the caller's voting weight across specified gauges.
    /// @param votedGauges A list of the gauges to vote for.
    /// @param weights A list of the corresponding weights.
    function vote(address[] calldata votedGauges, uint256[] calldata weights) external;

    /// @notice Claims voting incentives.
    /// @param to The recipient of the voting incentives.
    /// @param voteEpoch The voting epoch.
    /// @param votedGauge The voted gauge.
    /// @param tokens The tokens to claim.
    function claim(address to, uint256 voteEpoch, address votedGauge, address[] calldata tokens) external;

    /// @notice Increments the epoch.
    function incrementEpoch() external;
}
