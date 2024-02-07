// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Midnight} from "../src/token/Midnight.sol";
import {IVoteEscrow, VoteEscrow, TransferableVoteEscrowedMidnight} from "../src/token/VoteEscrow.sol";

contract VoterEscrowTest is Test {
    Midnight midnight = new Midnight(address(this), address(this));
    VoteEscrow voteEscrow = new VoteEscrow(address(midnight));
    TransferableVoteEscrowedMidnight transferableVeMidnight =
        TransferableVoteEscrowedMidnight(voteEscrow.transferableVoteEscrowedMidnight());

    function setUp() public {
        midnight.mint(address(this), type(uint256).max);
        midnight.approve(address(voteEscrow), type(uint256).max);
    }

    function toTransferType(bool isTransferUnlock) internal pure returns (IVoteEscrow.UnlockType) {
        return isTransferUnlock ? IVoteEscrow.UnlockType.Transfer : IVoteEscrow.UnlockType.Underlying;
    }

    function testWeight(uint128[64] memory amounts, uint16[64] memory lengths, bool[64] memory isTransferUnlock)
        public
    {
        for (uint256 i = 0; i < amounts.length; i++) {
            amounts[i] = uint128(bound(amounts[i], 1, type(uint128).max));
            voteEscrow.lock(address(this), amounts[i]);
            voteEscrow.unlock(amounts[i], toTransferType(isTransferUnlock[i]));
            skip(lengths[i]);
        }

        uint256 totalWeight;
        for (uint256 i = 0; i < 256; i++) {
            (IVoteEscrow.UnlockType unlockType, uint256 value, uint256 timestamp) = voteEscrow.unlockingLocks(i);
            uint256 duration = unlockType == IVoteEscrow.UnlockType.Transfer ? 12 weeks : 208 weeks;
            uint256 lockedDuration = block.timestamp - timestamp;
            if (lockedDuration <= duration) totalWeight += value * (duration - lockedDuration) / duration;
        }

        assertEq(totalWeight, voteEscrow.weight(address(this)));
    }

    function testLockWeight(uint208 amount, uint248 length, bool isTransferUnlock) public {
        amount = uint208(bound(amount, 1, type(uint208).max));
        voteEscrow.lock(address(this), amount);
        voteEscrow.unlock(amount, toTransferType(isTransferUnlock));
        skip(length);

        uint256 duration = isTransferUnlock ? 12 weeks : 208 weeks;
        uint256 weight = block.timestamp > duration ? 0 : amount * (duration - length) / duration;
        assertEq(voteEscrow.lockWeight(0), weight);
    }

    function testLocks(uint128[64] memory amounts, bool[64] memory isTransferUnlock) public {
        uint256[64] memory numbers;
        for (uint256 i = 0; i < amounts.length; i++) {
            amounts[i] = uint128(bound(amounts[i], 1, type(uint128).max));
            voteEscrow.lock(address(this), amounts[i]);
            voteEscrow.unlock(amounts[i], toTransferType(isTransferUnlock[i]));
            numbers[i] = i;
        }

        assertEq(keccak256(abi.encodePacked(voteEscrow.locks(address(this)))), keccak256(abi.encodePacked(numbers)));
    }

    function testLock(uint208 amount) public {
        amount = uint208(bound(amount, 1, type(uint208).max));
        voteEscrow.lock(address(this), amount);

        assertEq(amount, voteEscrow.balanceOf(address(this)));
        assertEq(amount, voteEscrow.weight(address(this)));
        assertEq(amount, type(uint256).max - midnight.balanceOf(address(this)));
    }

    function testLockInvalidAmount() public {
        vm.expectRevert(IVoteEscrow.InvalidAmount.selector);
        voteEscrow.lock(address(this), 0);
    }

    function testUnlock(uint208 amount, bool isTransferUnlock) public {
        amount = uint208(bound(amount, 1, type(uint208).max));
        voteEscrow.lock(address(this), amount);
        voteEscrow.unlock(amount, toTransferType(isTransferUnlock));

        assertEq(amount, voteEscrow.lockWeight(0));
        assertEq(voteEscrow.locks(address(this)).length, 1);
    }

    function testUnlockInvalidAmount() public {
        vm.expectRevert(IVoteEscrow.InvalidAmount.selector);
        voteEscrow.unlock(0, IVoteEscrow.UnlockType.Transfer);
    }

    function testRelock(uint208 amount, bool isTransferUnlock) public {
        amount = uint208(bound(amount, 1, type(uint208).max));
        voteEscrow.lock(address(this), amount);
        voteEscrow.unlock(amount, toTransferType(isTransferUnlock));
        voteEscrow.relock(0);

        (, uint256 value, uint256 timestamp) = voteEscrow.unlockingLocks(0);
        assertEq(voteEscrow.locks(address(this)).length, 0);
        assertEq(value, 0);
        assertEq(timestamp, 0);
    }

    function testRelockForbidden(uint208 amount, bool isTransferUnlock) public {
        amount = uint208(bound(amount, 1, type(uint208).max));
        voteEscrow.lock(address(1), amount);
        vm.startPrank(address(1));
        voteEscrow.unlock(amount, toTransferType(isTransferUnlock));
        vm.stopPrank();

        vm.expectRevert(IVoteEscrow.Forbidden.selector);
        voteEscrow.relock(0);
    }

    function testClaim(uint208 amount, bool isTransferUnlock) public {
        amount = uint208(bound(amount, 1, type(uint208).max));
        voteEscrow.lock(address(this), amount);
        voteEscrow.unlock(amount, toTransferType(isTransferUnlock));
        skip(208 weeks);
        voteEscrow.claim(0);

        isTransferUnlock
            ? assertEq(transferableVeMidnight.balanceOf(address(this)), amount)
            : assertEq(midnight.balanceOf(address(this)), type(uint256).max);
    }

    function testClaimForbidden(uint208 amount, bool isTransferUnlock) public {
        amount = uint208(bound(amount, 1, type(uint208).max));
        voteEscrow.lock(address(1), amount);
        vm.startPrank(address(1));
        voteEscrow.unlock(amount, toTransferType(isTransferUnlock));
        vm.stopPrank();

        vm.expectRevert(IVoteEscrow.Forbidden.selector);
        voteEscrow.claim(0);
    }

    function testClaimLocked(uint208 amount, bool isTransferUnlock) public {
        amount = uint208(bound(amount, 1, type(uint208).max));
        voteEscrow.lock(address(this), amount);
        voteEscrow.unlock(amount, toTransferType(isTransferUnlock));

        vm.expectRevert(IVoteEscrow.Locked.selector);
        voteEscrow.claim(0);
    }
}
