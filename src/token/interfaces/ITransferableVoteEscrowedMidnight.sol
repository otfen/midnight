// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

interface ITransferableVoteEscrowedMidnight is IERC20, IERC20Permit {
    /// @notice Mints transferable vote escrowed tokens.
    /// @param to The recipient of the tokens.
    /// @param amount The amount of tokens to mint.
    function mint(address to, uint256 amount) external;

    /// @notice Burns transferable vote escrowed tokens for the underlying vote escrowed tokens.
    /// @param to The recipient of the underlying tokens.
    /// @param amount The amount of tokens to burn.
    function burn(address to, uint256 amount) external;
}
