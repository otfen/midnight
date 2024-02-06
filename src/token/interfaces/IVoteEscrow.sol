// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

interface IVoteEscrow is IERC20, IERC20Permit {
    /// @notice Thrown when a caller lacks permission to perform an action.
    error Forbidden();

    /// @notice An enum representing the unlock type.
    enum UnlockType {
        Transfer,
        Underlying
    }

    /// @notice A structure representing an unlocking lock.
    /// @param unlockType The unlock type.
    /// @param value The amount of tokens locked.
    /// @param timestamp The starting timestamp of the unlocking period.
    struct UnlockingLock {
        UnlockType unlockType;
        uint256 value;
        uint256 timestamp;
    }

    /// @notice Returns the address of the governance token.
    function midnight() external view returns (address);

    /// @notice Returns the address of the transferable vote escrowed governance token.
    function transferableVoteEscrowedMidnight() external view returns (address);

    /// @notice Returns the voting power of an account.
    /// @param account The account to retrieve the voting power for.
    function weight(address account) external view returns (uint256);

    /// @notice Returns the weight of an unlocking lock.
    /// @param id The lock identifier.
    function lockWeight(uint256 id) external view returns (uint256);

    /// @notice Returns the unlocking locks owned by an account.
    /// @param account The account to retrieve unlocking locks for.
    function locks(address account) external view returns (uint256[] memory);

    /// @notice Locks governance tokens.
    /// @param to The recipient of the locked governance tokens.
    /// @param amount The amount of governance tokens to lock.
    function lock(address to, uint256 amount) external;

    /// @notice Starts the unlocking period of vote escrowed governance tokens.
    /// @param amount The amount of vote escrowed governance tokens to unlock.
    /// @param unlockType The unlock type.
    function unlock(uint256 amount, UnlockType unlockType) external;

    /// @notice Relocks unlocking governance tokens.
    /// @param id The lock identifier.
    function relock(uint256 id) external;

    /// @notice Claims unlocked governance tokens.
    /// @param id The lock identifier.
    function claim(uint256 id) external;
}
