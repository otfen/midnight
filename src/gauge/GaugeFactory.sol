// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IGaugeFactory} from "./interfaces/IGaugeFactory.sol";
import {Gauge} from "./Gauge.sol";

contract GaugeFactory is IGaugeFactory, Ownable {
    address public immutable implementation;
    address public voter;

    constructor(address governor, address _voter) Ownable(governor) {
        voter = _voter;
        implementation = address(new Gauge());
    }

    function setVoter(address _voter) public onlyOwner {
        voter = _voter;
        emit VoterUpdated(voter);
    }

    function createGauge(address pool, address rewardToken) public returns (address instance) {
        instance = Clones.clone(implementation);
        Gauge(instance).initialize(pool, rewardToken);
        emit GaugeCreated(pool, rewardToken);
    }
}
