// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IVoteEscrow} from "./interfaces/IVoteEscrow.sol";

contract TransferableVoteEscrowedMidnight is Ownable, ERC20, ERC20Permit {
    constructor()
        ERC20("Vote Escrowed Midnight", "veMidnight")
        ERC20Permit("Vote Escrowed Midnight")
        Ownable(msg.sender)
    {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) external {
        _burn(msg.sender, amount);
        IVoteEscrow(owner()).transfer(to, amount);
    }
}
