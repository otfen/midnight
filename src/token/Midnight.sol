// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract Midnight is AccessControl, ERC20, ERC20Permit {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(address governor, address voter) ERC20("Midnight", "NIGHT") ERC20Permit("Midnight") {
        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(MINTER_ROLE, voter);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
