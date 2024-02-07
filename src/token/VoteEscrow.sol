// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Permit, ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IVoteEscrow} from "./interfaces/IVoteEscrow.sol";
import {TransferableVoteEscrowedMidnight} from "./TransferableVoteEscrowedMidnight.sol";

contract VoteEscrow is ERC20, ERC20Permit, ERC20Votes, IVoteEscrow {
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 internal constant LOCK_DURATION = 208 weeks;
    uint256 internal constant TRANSFER_LOCK_DURATION = 12 weeks;
    uint256 internal lockIndex;

    address public immutable midnight;
    address public immutable transferableVoteEscrowedMidnight = address(new TransferableVoteEscrowedMidnight());

    mapping(uint256 => UnlockingLock) public unlockingLocks;
    mapping(address => EnumerableSet.UintSet) internal ownedLocks;

    constructor(address _midnight)
        ERC20("Vote Escrowed Midnight", "veMidnight")
        ERC20Permit("Vote Escrowed Midnight")
    {
        midnight = _midnight;
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    function nonces(address owner) public view override(ERC20Permit, IERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    function weight(address account) external view returns (uint256 _weight) {
        for (uint256 i = 0; i < ownedLocks[account].length(); ++i) {
            _weight += lockWeight(ownedLocks[account].at(i));
        }
        _weight += balanceOf(account);
    }

    function lockWeight(uint256 id) public view returns (uint256) {
        UnlockingLock memory _lock = unlockingLocks[id];
        uint256 duration = _lock.unlockType == UnlockType.Transfer ? TRANSFER_LOCK_DURATION : LOCK_DURATION;
        uint256 lockedDuration = block.timestamp - _lock.timestamp;
        if (lockedDuration > duration) return 0;
        return _lock.value * (duration - lockedDuration) / duration;
    }

    function locks(address account) external view returns (uint256[] memory) {
        return ownedLocks[account].values();
    }

    function lock(address to, uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        IERC20(midnight).transferFrom(msg.sender, address(this), amount);
        _mint(to, amount);
    }

    function unlock(uint256 amount, UnlockType unlockType) external {
        if (amount == 0) revert InvalidAmount();
        _burn(msg.sender, amount);
        unlockingLocks[lockIndex] = UnlockingLock(unlockType, amount, block.timestamp);
        ownedLocks[msg.sender].add(lockIndex);
        lockIndex++;
    }

    function relock(uint256 id) external {
        if (!ownedLocks[msg.sender].contains(id)) revert Forbidden();
        _mint(msg.sender, unlockingLocks[id].value);
        _deleteLock(id);
    }

    function claim(uint256 id) external {
        if (!ownedLocks[msg.sender].contains(id)) revert Forbidden();
        UnlockingLock memory unlockingLock = unlockingLocks[id];

        if (unlockingLock.unlockType == UnlockType.Transfer) {
            if (block.timestamp < unlockingLock.timestamp + LOCK_DURATION) revert Locked();
            _mint(transferableVoteEscrowedMidnight, unlockingLock.value);
            TransferableVoteEscrowedMidnight(transferableVoteEscrowedMidnight).mint(msg.sender, unlockingLock.value);
        } else if (unlockingLock.unlockType == UnlockType.Underlying) {
            if (block.timestamp < unlockingLock.timestamp + TRANSFER_LOCK_DURATION) revert Locked();
            IERC20(midnight).transfer(msg.sender, unlockingLocks[id].value);
        }

        _deleteLock(id);
    }

    function _deleteLock(uint256 id) internal {
        ownedLocks[msg.sender].remove(id);
        delete unlockingLocks[id];
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        if (from != address(0) && to != address(0) && from != address(this) && from != transferableVoteEscrowedMidnight)
        {
            revert Forbidden();
        }
        super._update(from, to, value);
    }
}
