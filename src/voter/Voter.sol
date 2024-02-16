// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {IVoter} from "./interfaces/IVoter.sol";
import {IGauge} from "../gauge/interfaces/IGauge.sol";
import {IVoteEscrow} from "../token/interfaces/IVoteEscrow.sol";
import {Midnight} from "../token/Midnight.sol";

contract Voter is IVoter, AccessControl, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    bytes32 public constant GAUGE_COMMITTEE = keccak256("GAUGE_COMMITTEE");
    EnumerableSet.AddressSet internal _gauges;

    address public immutable midnight;
    address public immutable veMidnight;

    uint256 public epoch;
    uint256 public epochEmissionsBps = 20;
    uint256 public epochTotalWeight;
    mapping(uint256 => mapping(address => uint256)) public gaugeWeight;
    mapping(uint256 => mapping(address => EnumerableMap.AddressToUintMap)) internal _votes;

    constructor(address governor, address _midnight, address _veMidnight) {
        _grantRole(DEFAULT_ADMIN_ROLE, governor);

        midnight = _midnight;
        veMidnight = _veMidnight;
        epoch = block.timestamp / 1 weeks;
    }

    function setEpochEmissionsBps(uint256 _epochEmissionsBps) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_epochEmissionsBps > 50) revert InvalidRate();
        epochEmissionsBps = _epochEmissionsBps;
        emit EpochEmissionsUpdated(epochEmissionsBps);
    }

    function gauges() external view returns (address[] memory) {
        return _gauges.values();
    }

    function isGauge(address gauge) external view returns (bool) {
        return _gauges.contains(gauge);
    }

    function addGauge(address gauge) external onlyRole(GAUGE_COMMITTEE) {
        _gauges.add(gauge);
        emit GaugeAdded(gauge);
    }

    function removeGauge(address gauge) external onlyRole(GAUGE_COMMITTEE) {
        _gauges.remove(gauge);
        emit GaugeRemoved(gauge);
    }

    function votes(uint256 votingEpoch, address account) external view returns (address[] memory) {
        return _votes[votingEpoch][account].keys();
    }

    function voted(uint256 votingEpoch, address account) external view returns (bool) {
        return _votes[votingEpoch][account].length() > 0;
    }

    function voteWeight(uint256 votingEpoch, address account, address gauge) external view returns (uint256) {
        return _votes[votingEpoch][account].get(gauge);
    }

    function reset() public {
        address[] memory keys = _votes[epoch][msg.sender].keys();
        for (uint256 i = 0; i < keys.length; ++i) {
            address _gauge = keys[i];
            uint256 _weight = _votes[epoch][msg.sender].get(_gauge);
            gaugeWeight[epoch][_gauge] -= _weight;
            epochTotalWeight -= _weight;
            _votes[epoch][msg.sender].remove(_gauge);
        }
        emit Reset();
    }

    function vote(address[] calldata votedGauges, uint256[] calldata weights) external {
        reset();

        uint256 userTotalWeight;
        for (uint256 i = 0; i < votedGauges.length; i++) {
            address _gauge = votedGauges[i];
            if (!_gauges.contains(_gauge)) revert InvalidGauge();
            if (_votes[epoch][msg.sender].contains(_gauge)) revert DuplicateVote();

            uint256 _weight = weights[i];
            userTotalWeight += _weight;
            gaugeWeight[epoch][_gauge] += _weight;
            _votes[epoch][msg.sender].set(_gauge, _weight);
        }

        if (userTotalWeight > IVoteEscrow(veMidnight).weight(msg.sender)) revert InvalidWeight();
        epochTotalWeight += userTotalWeight;
        emit Vote(votedGauges, weights);
    }

    function claim(address to, uint256 voteEpoch, address votedGauge, address[] calldata tokens)
        external
        nonReentrant
    {
        if (voteEpoch == epoch) revert NotNewEpoch();
        uint256[] memory availableAmounts = IGauge(votedGauge).incentiveTokenAmounts(voteEpoch, tokens);
        uint256[] memory amounts = new uint256[](tokens.length);
        uint256 weight = _votes[voteEpoch][msg.sender].get(votedGauge);
        uint256 gaugeTotalWeight = gaugeWeight[voteEpoch][votedGauge];

        for (uint256 i = 0; i < tokens.length; i++) {
            amounts[i] = availableAmounts[i] * weight / gaugeTotalWeight;
        }

        gaugeWeight[voteEpoch][votedGauge] -= weight;
        _votes[voteEpoch][msg.sender].remove(votedGauge);
        IGauge(votedGauge).claimIncentivesFor(to, voteEpoch, tokens, amounts);
    }

    function distribute() internal {
        uint256 distributionAmount = Midnight(midnight).totalSupply() * epochEmissionsBps / 10000;
        Midnight(midnight).mint(address(this), distributionAmount);
        uint256 balance = IERC20(midnight).balanceOf(address(this));

        for (uint256 i = 0; i < _gauges.length(); i++) {
            address gauge = _gauges.at(i);
            uint256 emissions = balance * gaugeWeight[epoch][gauge] / epochTotalWeight;
            if (emissions == 0) continue;
            Midnight(midnight).transfer(gauge, emissions);
            IGauge(gauge).notifyRewardAmount(emissions);
        }
    }

    function incrementEpoch() external nonReentrant {
        if (block.timestamp / 1 weeks <= epoch) revert NotNewEpoch();
        distribute();
        epochTotalWeight = 0;
        epoch++;
        emit NewEpoch(epoch);
    }
}
