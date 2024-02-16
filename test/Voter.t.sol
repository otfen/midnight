// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {IVoteEscrow, VoteEscrow} from "../src/token/VoteEscrow.sol";
import {Midnight} from "../src/token/Midnight.sol";
import {IVoter, Voter} from "../src/voter/Voter.sol";
import {Gauge, GaugeFactory} from "../src/gauge/GaugeFactory.sol";
import {Pool, PoolFactory} from "../src/pool/PoolFactory.sol";

contract Token is ERC20 {
    constructor() ERC20("Midnight", "NIGHT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract VoterTest is Test {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet set;
    Midnight midnight = new Midnight(address(this), address(this));
    VoteEscrow voteEscrow = new VoteEscrow(address(midnight));
    Voter voter = new Voter(address(this), address(midnight), address(voteEscrow));
    GaugeFactory gaugeFactory = new GaugeFactory(address(this), address(voter));
    PoolFactory poolFactory = new PoolFactory(address(this));
    address pool = poolFactory.createPool(address(new Token()), address(new Token()), true, 30);

    function setUp() public {
        midnight.mint(address(this), type(uint128).max);
        midnight.approve(address(voteEscrow), type(uint128).max);
        midnight.grantRole(midnight.MINTER_ROLE(), address(voter));
        voteEscrow.lock(address(this), type(uint120).max);
        voter.grantRole(voter.GAUGE_COMMITTEE(), address(this));
    }

    function testGauges(address[] memory gauges) public {
        for (uint256 i = 0; i < gauges.length; i++) {
            set.add(gauges[i]);
            voter.addGauge(gauges[i]);
        }

        assertEq(set.values(), voter.gauges());
    }

    function testAddGauge(address gauge) public {
        voter.addGauge(gauge);
        assertEq(gauge, voter.gauges()[0]);
    }

    function testRemoveGauge(address gauge) public {
        voter.addGauge(gauge);
        voter.removeGauge(gauge);
        assertEq(voter.gauges().length, 0);
    }

    function testReset(address[64] memory gauges, uint96[64] memory weights) public {
        testVote(gauges, weights);
        voter.reset();

        for (uint256 i = 0; i < set.length(); i++) {
            assertEq(voter.gaugeWeight(0, set.at(i)), 0);
        }

        assertEq(voter.votes(0, address(this)).length, 0);
        assertEq(voter.epochTotalWeight(), 0);
    }

    function testVote(address[64] memory gauges, uint96[64] memory weights) public {
        uint256[] memory castedWeights = new uint256[](weights.length);
        for (uint256 i = 0; i < gauges.length; i++) {
            set.add(gauges[i]);
            voter.addGauge(gauges[i]);
            castedWeights[i] = weights[i];
        }

        voter.vote(set.values(), castedWeights);

        for (uint256 i = 0; i < set.length(); i++) {
            assertEq(weights[i], voter.voteWeight(0, address(this), set.at(i)));
        }

        assertEq(set.values(), voter.votes(0, address(this)));
    }

    function testVoteInvalidGauge(address[] memory gauges, uint256[] memory weights) public {
        vm.assume(gauges.length > 0);
        vm.expectRevert(IVoter.InvalidGauge.selector);
        voter.vote(gauges, weights);
    }

    function testVoteInvalidWeight(address gauge, uint256 weight) public {
        address[] memory gauges = new address[](1);
        uint256[] memory weights = new uint256[](1);

        gauges[0] = gauge;
        weights[0] = bound(weight, 1, type(uint256).max);
        voter.addGauge(gauge);

        vm.startPrank(address(1));
        vm.expectRevert(IVoter.InvalidWeight.selector);
        voter.vote(gauges, weights);
    }

    function testVoteDuplicateVote(address gauge, uint256 weight) public {
        address[] memory gauges = new address[](2);
        uint256[] memory weights = new uint256[](2);

        gauges[0] = gauge;
        gauges[1] = gauge;
        weights[0] = bound(weight, 1, type(uint256).max);
        weights[1] = bound(weight, 1, type(uint256).max);
        voter.addGauge(gauge);

        vm.startPrank(address(1));
        vm.expectRevert(IVoter.DuplicateVote.selector);
        voter.vote(gauges, weights);
    }

    function testClaim(uint256 incentives) public {
        Token token = new Token();
        token.mint(address(this), type(uint256).max);
        incentives = bound(incentives, 1, type(uint256).max);

        address[] memory gauges = new address[](1);
        address[] memory tokens = new address[](1);
        uint256[] memory weights = new uint256[](1);

        address gauge = gaugeFactory.createGauge(pool, address(midnight));
        token.approve(gauge, incentives);
        Gauge(gauge).addIncentive(0, address(token), incentives);

        tokens[0] = address(token);
        gauges[0] = gauge;
        weights[0] = 1;

        voter.addGauge(gauge);
        voter.vote(gauges, weights);
        skip(1 weeks);
        voter.incrementEpoch();

        voter.claim(address(this), 0, gauge, tokens);
        assertEq(token.balanceOf(address(this)), type(uint256).max);
    }

    function testClaimMultipleGauges(uint112[64] memory weights, uint128[64] memory incentives) public {
        Token token = new Token();
        token.mint(address(this), type(uint256).max);

        address[] memory gauges = new address[](weights.length);
        uint256[] memory castedWeights = new uint256[](weights.length);
        address[] memory tokens = new address[](1);
        tokens[0] = address(token);

        for (uint256 i = 0; i < incentives.length; i++) {
            uint256 incentive = bound(incentives[i], 1, type(uint128).max);
            gauges[i] = gaugeFactory.createGauge(pool, address(midnight));
            castedWeights[i] = bound(weights[i], 1, type(uint112).max);

            token.approve(gauges[i], incentive);
            Gauge(gauges[i]).addIncentive(0, address(token), incentive);
            voter.addGauge(gauges[i]);
        }

        voter.vote(gauges, castedWeights);
        skip(1 weeks);
        voter.incrementEpoch();

        for (uint256 i = 0; i < gauges.length; i++) {
            voter.claim(address(this), 0, gauges[i], tokens);
        }

        assertEq(token.balanceOf(address(this)), type(uint256).max);
    }

    function testClaimMultipleVoters(
        address[16] memory voters,
        uint32[8][16] memory weights,
        uint128[8] memory incentives
    ) public {
        Token token = new Token();
        token.mint(address(this), type(uint256).max);

        address[] memory gauges = new address[](incentives.length);
        address[] memory tokens = new address[](1);
        tokens[0] = address(token);

        for (uint256 i = 0; i < incentives.length; i++) {
            uint256 incentive = bound(incentives[i], 1, type(uint128).max);
            address gauge = gaugeFactory.createGauge(pool, address(midnight));

            gauges[i] = gauge;
            voter.addGauge(gauge);
            token.approve(gauge, incentive);
            Gauge(gauge).addIncentive(0, address(token), incentive);
        }

        for (uint256 i = 0; i < voters.length; i++) {
            if (voters[i] == address(0)) set.add(address(1));
            else set.add(voters[i]);
        }

        for (uint256 i = 0; i < set.length(); i++) {
            voteEscrow.lock(set.at(i), type(uint64).max);
            vm.startPrank(set.at(i));

            uint256[] memory castedWeights = new uint256[](weights.length);
            for (uint256 j = 0; j < weights[i].length; j++) {
                castedWeights[j] = bound(weights[i][j], 1, type(uint32).max);
            }

            voter.vote(gauges, castedWeights);
            vm.stopPrank();
        }

        skip(1 weeks);
        voter.incrementEpoch();
        address account = address(this);

        for (uint256 i = 0; i < set.length(); i++) {
            for (uint256 j = 0; j < gauges.length; j++) {
                vm.startPrank(set.at(i));
                voter.claim(address(account), 0, gauges[j], tokens);
                vm.stopPrank();
            }
        }

        assertEq(token.balanceOf(address(this)), type(uint256).max);
    }

    function testClaimMultipleTokens(uint256[] memory incentives) public {
        address[] memory gauges = new address[](1);
        uint256[] memory weights = new uint256[](1);
        address[] memory tokens = new address[](incentives.length);

        address gauge = gaugeFactory.createGauge(pool, address(midnight));
        voter.addGauge(gauge);

        gauges[0] = gauge;
        weights[0] = 1;

        for (uint256 i = 0; i < incentives.length; i++) {
            incentives[i] = uint256(bound(incentives[i], 1, type(uint256).max));
            Token token = new Token();
            tokens[i] = address(token);
            token.mint(address(this), type(uint256).max);
            token.approve(gauge, incentives[i]);
            Gauge(gauge).addIncentive(0, address(token), incentives[i]);
        }

        voter.vote(gauges, weights);
        skip(1 weeks);
        voter.incrementEpoch();
        voter.claim(address(this), 0, gauge, tokens);

        for (uint256 i = 0; i < tokens.length; i++) {
            assertEq(Token(tokens[i]).balanceOf(address(this)), type(uint256).max);
        }
    }

    function testClaimNotNewEpoch(address gauge, address[] memory tokens) public {
        vm.expectRevert(IVoter.NotNewEpoch.selector);
        voter.claim(address(this), 0, gauge, tokens);
    }

    function testClaimWithoutVote(address[] memory tokens) public {
        skip(1 weeks);
        address gauge = gaugeFactory.createGauge(pool, address(midnight));
        voter.incrementEpoch();
        vm.expectRevert(abi.encodeWithSelector(EnumerableMap.EnumerableMapNonexistentKey.selector, gauge));
        voter.claim(address(this), 0, gauge, tokens);
    }

    function testIncrementEpoch(uint96[64] memory weights) public {
        address[64] memory gauges;
        for (uint256 i = 0; i < weights.length; i++) {
            gauges[i] = gaugeFactory.createGauge(pool, address(midnight));
        }

        testVote(gauges, weights);
        uint256 emissions = Midnight(midnight).totalSupply() / 500;
        uint256 totalWeight = voter.epochTotalWeight();

        skip(1 weeks);
        voter.incrementEpoch();

        for (uint256 i = 0; i < gauges.length; i++) {
            assertEq(midnight.balanceOf(gauges[i]), emissions * voter.gaugeWeight(0, gauges[i]) / totalWeight);
        }
    }

    function testIncrementEpochNotNewEpoch() public {
        vm.expectRevert(IVoter.NotNewEpoch.selector);
        voter.incrementEpoch();
    }
}
