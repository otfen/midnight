// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IPoolFactory} from "./interfaces/IPoolFactory.sol";
import {Pool} from "./Pool.sol";

contract PoolFactory is IPoolFactory, Ownable {
    address public immutable implementation;

    uint256 public protocolFee = 1200;
    address public protocolFeeHandler;
    mapping(uint256 => bool) public isFeeTierApproved;

    mapping(address => mapping(address => mapping(bool => mapping(uint256 => address)))) public getPool;
    address[] public pools;

    constructor(address governor) Ownable(governor) {
        isFeeTierApproved[1] = true;
        isFeeTierApproved[5] = true;
        isFeeTierApproved[10] = true;
        isFeeTierApproved[30] = true;
        isFeeTierApproved[100] = true;
        implementation = address(new Pool());
    }

    function poolsLength() external view returns (uint256) {
        return pools.length;
    }

    function setFeeTier(uint256 feeTier, bool approved) external onlyOwner {
        if (feeTier > 1000) revert InvalidFee();
        isFeeTierApproved[feeTier] = approved;
        emit FeeTierUpdate(feeTier, approved);
    }

    function setProtocolFee(uint256 _protocolFee) external onlyOwner {
        if (_protocolFee > 2000) revert InvalidFee();
        protocolFee = _protocolFee;
        emit ProtocolFeeUpdate(_protocolFee);
    }

    function setProtocolFeeHandler(address _protocolFeeHandler) external onlyOwner {
        protocolFeeHandler = _protocolFeeHandler;
        emit ProtocolFeeHandlerUpdate(_protocolFeeHandler);
    }

    function createPool(address tokenA, address tokenB, bool stable, uint256 feeTier) external returns (address pool) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == token1) revert IdenticalAddress();
        if (token0 == address(0)) revert ZeroAddress();
        if (getPool[token0][token1][stable][feeTier] != address(0)) revert PoolExists();
        if (!isFeeTierApproved[feeTier]) revert UnapprovedFeeTier();

        bytes32 salt = keccak256(abi.encodePacked(token0, token1, stable, feeTier));
        pool = Clones.cloneDeterministic(implementation, salt);
        Pool(pool).initialize(token0, token1, stable, feeTier);

        getPool[token0][token1][stable][feeTier] = pool;
        getPool[token1][token0][stable][feeTier] = pool;
        pools.push(pool);

        emit PoolCreated(token0, token1, stable, feeTier, pool, pools.length);
    }
}
