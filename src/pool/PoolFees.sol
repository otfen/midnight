// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPoolFees} from "./interfaces/IPoolFees.sol";
import {IPool} from "./interfaces/IPool.sol";
import {IPoolFactory} from "./interfaces/IPoolFactory.sol";

contract PoolFees is IPoolFees {
    using SafeERC20 for IERC20;

    address public immutable pool;
    address public immutable factory;
    address public immutable token0;
    address public immutable token1;
    uint256 public protocolFees0;
    uint256 public protocolFees1;

    constructor(address _token0, address _token1, address _factory) {
        pool = msg.sender;
        factory = _factory;
        token0 = _token0;
        token1 = _token1;
    }

    function claimFeesFor(address recipient, uint256 amount0, uint256 amount1) external {
        if (msg.sender != pool) revert Forbidden();
        if (amount0 > 0) IERC20(token0).safeTransfer(recipient, amount0);
        if (amount1 > 0) IERC20(token1).safeTransfer(recipient, amount1);
    }

    function notifyProtocolFee(uint256 amount0, uint256 amount1) public {
        if (msg.sender != pool) revert Forbidden();
        if (amount0 > 0) protocolFees0 += amount0;
        if (amount1 > 0) protocolFees1 += amount1;
    }

    function withdrawProtocolFees(address recipient, uint256 amount0, uint256 amount1) public {
        if (msg.sender != IPoolFactory(factory).protocolFeeHandler()) revert Forbidden();
        protocolFees0 -= amount0;
        protocolFees1 -= amount1;
        IERC20(token0).safeTransfer(recipient, amount0);
        IERC20(token1).safeTransfer(recipient, amount1);
        emit Withdrawal(recipient, amount0, amount1);
    }
}
