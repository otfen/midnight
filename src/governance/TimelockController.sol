// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract MidnightTimelockController is TimelockController {
    constructor() TimelockController(3 days, new address[](0), new address[](0), msg.sender) {}
}
