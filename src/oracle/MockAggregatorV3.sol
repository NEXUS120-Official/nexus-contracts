// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

contract MockAggregatorV3 {
    uint8 public immutable decimals;
    int256 private _answer;
    uint80 private _roundId;
    uint256 private _updatedAt;
    uint80 private _answeredInRound;

    constructor(uint8 decimals_, int256 initialAnswer_) {
        decimals = decimals_;
        _setAnswer(initialAnswer_);
    }

    function setAnswer(int256 newAnswer) external {
        _setAnswer(newAnswer);
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _answer, _updatedAt, _updatedAt, _answeredInRound);
    }

    function _setAnswer(int256 newAnswer) internal {
        require(newAnswer > 0, "MOCK: answer <= 0");
        _roundId += 1;
        _answer = newAnswer;
        _updatedAt = block.timestamp;
        _answeredInRound = _roundId;
    }
}
