// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGauge is IERC20 {
    /// @notice Thrown when a caller lacks permission to perform an action.
    error Forbidden();

    /// @notice Thrown when an amount passed is equal to zero.
    error InvalidAmount();

    /// @notice Thrown when the epoch reward exceeds the balance of the contract.
    error RewardExceedsBalance();

    /// @notice Thrown when an incentive is added to a past epoch.
    error PastEpoch();

    /// @notice Emitted when a reward is added.
    /// @param reward The amount of reward added.
    event RewardAdded(uint256 reward);

    /// @notice Emitted when pool tokens are staked.
    /// @param amount The amount of pool tokens staked.
    event Staked(uint256 amount);

    /// @notice Emitted when pool tokens are unstaked.
    /// @param amount The amount of pool tokens unstaked.
    event Withdrawn(uint256 amount);

    /// @notice Emitted when rewards are paid.
    /// @param reward The amount of rewards paid.
    event RewardPaid(uint256 reward);

    /// @notice A structure representing a voting incentive.
    /// @param token The incentive token.
    /// @param amount The amount of the incentive token.
    struct Incentive {
        address token;
        uint256 amount;
    }

    /// @notice Returns the address of the bonded pool.
    function pool() external view returns (address);

    /// @notice Returns the address of the bonded pool's first pooled token.
    function token0() external view returns (address);

    /// @notice Returns the address of the bonded pool's second pooled token.
    function token1() external view returns (address);

    /// @notice Returns the address of the reward token.
    function rewardToken() external view returns (address);

    /// @notice Returns the concluding timestamp of the current reward period.
    function periodFinish() external view returns (uint256);

    /// @notice Returns the amount of rewards distributed per second.
    function rewardRate() external view returns (uint256);

    /// @notice Returns the timestamp of the last reward update.
    function lastUpdateTime() external view returns (uint256);

    /// @notice Returns the last updated reward per token.
    function rewardPerTokenStored() external view returns (uint256);

    /// @notice Returns the last updated reward per token for an account.
    function rewardPerTokenPaid(address) external view returns (uint256);

    /// @notice Returns the amount of unclaimed rewards for an account.
    function rewards(address) external view returns (uint256);

    /// @notice Initializes the gauge. Called by the gauge factory after contract creation.
    /// @param _pool The address of the bonded pool.
    /// @param _rewardToken The address of the reward token.
    function initialize(address _pool, address _rewardToken) external;

    /// @notice Returns the last applicable reward time.
    function lastTimeRewardApplicable() external view returns (uint256);

    /// @notice Returns the reward per token.
    function rewardPerToken() external view returns (uint256);

    /// @notice Returns the amount of rewards earned for a specified account.
    /// @param account The account.
    function earned(address account) external view returns (uint256);

    /// @notice Returns the total reward amount of the current reward period.
    function getRewardForDuration() external view returns (uint256);

    /// @notice Stakes pool tokens.
    /// @param amount The amount of pool tokens to stake.
    /// @param to The recipient of the gauge tokens.
    function stake(uint256 amount, address to) external;

    /// @notice Unstakes pool tokens.
    /// @param amount The amount of pool tokens to unstake.
    /// @param to The recipient of the pool tokens.
    function withdraw(uint256 amount, address to) external;

    /// @notice Claims earned rewards.
    function claim() external;

    /// @notice Adds accumulated fees to the current epoch's voting incentives.
    function claimFees() external;

    /// @notice Returns the available incentive tokens for a given epoch.
    /// @param epoch The epoch number.
    function incentiveTokens(uint256 epoch) external view returns (address[] memory);

    /// @notice Returns the amount of a specified incentive token available for a given epoch.
    /// @param epoch The epoch number.
    /// @param token The incentive token.
    function incentiveTokenAmount(uint256 epoch, address token) external view returns (uint256 amount);

    /// @notice Returns the amounts of incentive tokens available for a given epoch.
    /// @param epoch The epoch number.
    /// @param tokens A list of incentive tokens.
    function incentiveTokenAmounts(uint256 epoch, address[] calldata tokens) external view returns (uint256[] memory);

    /// @notice Returns a list of available voting incentives for a given epoch.
    /// @param epoch The epoch number.
    function incentiveList(uint256 epoch) external view returns (Incentive[] memory);

    /// @notice Adds a voting incentive.
    /// @param epoch The epoch number.
    /// @param token The incentive token.
    /// @param amount The incentive amount.
    function addIncentive(uint256 epoch, address token, uint256 amount) external;

    /// @notice Claims voting incentives.
    /// @param to The recipient of the voting incentives.
    /// @param epoch The epoch number.
    /// @param tokens A list of the voting incentive tokens.
    /// @param amounts A list of the corresponding amounts of each voting incentive token.
    function claimIncentivesFor(address to, uint256 epoch, address[] calldata tokens, uint256[] calldata amounts)
        external;

    /// @notice Notifies the contract of rewards.
    /// @param reward The reward amount.
    function notifyRewardAmount(uint256 reward) external;
}
