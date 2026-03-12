// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

contract MockAggregatorV3 {
    uint8 public decimals;

    uint80 public roundId;
    int256 public answer;
    uint256 public startedAt;
    uint256 public updatedAt;
    uint80 public answeredInRound;

    constructor(uint8 decimals_) {
        decimals = decimals_;
        roundId = 1;
        answeredInRound = 1;
    }

    function setRoundData(int256 answer_, uint256 updatedAt_) external {
        answer = answer_;
        updatedAt = updatedAt_;
        startedAt = updatedAt_;
        roundId += 1;
        answeredInRound = roundId;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
