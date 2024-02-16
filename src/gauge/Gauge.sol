// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ERC20, ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {IGauge} from "./interfaces/IGauge.sol";
import {IGaugeFactory} from "./interfaces/IGaugeFactory.sol";
import {IPool} from "../pool/interfaces/IPool.sol";
import {IVoter} from "../voter/interfaces/IVoter.sol";

contract Gauge is ReentrancyGuard, Initializable, ERC20, ERC20Permit, IGauge {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using SafeERC20 for IERC20;

    uint256 internal immutable REWARDS_DURATION = 7 days;

    address public pool;
    address public token0;
    address public token1;
    address public factory;
    address public rewardToken;

    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public rewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(uint256 => EnumerableMap.AddressToUintMap) internal _incentives;

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        rewards[account] = earned(account);
        rewardPerTokenPaid[account] = rewardPerTokenStored;
        _;
    }

    constructor() ERC20("Midnight Gauge", "NIGHT") ERC20Permit("Midnight Gauge") {}

    function initialize(address _pool, address _rewardToken) external initializer {
        pool = _pool;
        token0 = IPool(_pool).token0();
        token1 = IPool(_pool).token1();
        rewardToken = _rewardToken;
        factory = msg.sender;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) return rewardPerTokenStored;
        return rewardPerTokenStored + (lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18 / totalSupply();
    }

    function earned(address account) public view returns (uint256) {
        return balanceOf(account) * (rewardPerToken() - rewardPerTokenPaid[account]) / 1e18 + rewards[account];
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * REWARDS_DURATION;
    }

    function stake(uint256 amount, address to) external nonReentrant updateReward(to) {
        if (amount == 0) revert InvalidAmount();
        _mint(to, amount);
        IERC20(pool).transferFrom(msg.sender, address(this), amount);
        emit Staked(amount);
    }

    function withdraw(uint256 amount, address to) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert InvalidAmount();
        _burn(msg.sender, amount);
        IERC20(pool).transfer(to, amount);
        emit Withdrawn(amount);
    }

    function claim() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward == 0) return;
        rewards[msg.sender] = 0;
        IERC20(rewardToken).transfer(msg.sender, reward);
        emit RewardPaid(reward);
    }

    function incentiveTokens(uint256 epoch) external view returns (address[] memory) {
        return _incentives[epoch].keys();
    }

    function incentiveTokenAmount(uint256 epoch, address token) public view returns (uint256 amount) {
        (, amount) = _incentives[epoch].tryGet(token);
    }

    function incentiveTokenAmounts(uint256 epoch, address[] calldata tokens) external view returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            amounts[i] = incentiveTokenAmount(epoch, tokens[i]);
        }
        return amounts;
    }

    function incentiveList(uint256 epoch) external view returns (Incentive[] memory) {
        uint256 length = _incentives[epoch].length();
        Incentive[] memory list = new Incentive[](length);
        for (uint256 i = 0; i < _incentives[epoch].length(); i++) {
            (address token, uint256 amount) = _incentives[epoch].at(i);
            list[i] = Incentive(token, amount);
        }
        return list;
    }

    function _addIncentive(uint256 epoch, address token, uint256 amount) internal {
        if (epoch < IVoter(IGaugeFactory(factory).voter()).epoch()) revert PastEpoch();
        (, uint256 currentIncentiveAmount) = _incentives[epoch].tryGet(token);
        _incentives[epoch].set(token, currentIncentiveAmount + amount);
    }

    function claimFees() external {
        uint256 epoch = IVoter(IGaugeFactory(factory).voter()).epoch();
        (uint256 fees0, uint256 fees1) = IPool(pool).claim();
        if (fees0 > 0) _addIncentive(epoch, token0, fees0);
        if (fees1 > 0) _addIncentive(epoch, token0, fees1);
    }

    function addIncentive(uint256 epoch, address token, uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _addIncentive(epoch, token, amount);
    }

    function claimIncentivesFor(address to, uint256 epoch, address[] calldata tokens, uint256[] calldata amounts)
        external
    {
        if (msg.sender != IGaugeFactory(factory).voter()) revert Forbidden();
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 amount = amounts[i];

            _incentives[epoch].set(token, incentiveTokenAmount(epoch, token) - amount);
            IERC20(token).safeTransfer(to, amount);
        }
    }

    function notifyRewardAmount(uint256 reward) external updateReward(address(0)) {
        if (msg.sender != IGaugeFactory(factory).voter()) revert Forbidden();
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / REWARDS_DURATION;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / REWARDS_DURATION;
        }

        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        if (rewardRate * REWARDS_DURATION > balance) revert RewardExceedsBalance();

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + REWARDS_DURATION;
        emit RewardAdded(reward);
    }

    function _update(address from, address to, uint256 value) internal override updateReward(from) updateReward(to) {
        super._update(from, to, value);
    }
}
