// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

interface IAggregatorV3 {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract OracleModule is AccessControl {
    IAggregatorV3 public feed;
    uint256 public maxDelay;

    event OracleFeedSet(address indexed feed, address indexed by);
    event OracleMaxDelaySet(uint256 maxDelay, address indexed by);

    constructor(address admin, address feed_, uint256 maxDelay_) {
        require(admin != address(0), "ORACLE: admin is zero");
        require(feed_ != address(0), "ORACLE: feed is zero");
        require(maxDelay_ > 0, "ORACLE: maxDelay is zero");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        feed = IAggregatorV3(feed_);
        maxDelay = maxDelay_;

        emit OracleFeedSet(feed_, admin);
        emit OracleMaxDelaySet(maxDelay_, admin);
    }

    function setFeed(address feed_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(feed_ != address(0), "ORACLE: feed is zero");
        feed = IAggregatorV3(feed_);
        emit OracleFeedSet(feed_, msg.sender);
    }

    function setMaxDelay(uint256 maxDelay_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(maxDelay_ > 0, "ORACLE: maxDelay is zero");
        maxDelay = maxDelay_;
        emit OracleMaxDelaySet(maxDelay_, msg.sender);
    }

    function getPrice()
        external
        view
        returns (uint256 price, uint256 updatedAt, uint8 decimals)
    {
        decimals = feed.decimals();

        (, int256 answer,, uint256 upd,) = feed.latestRoundData();
        require(answer > 0, "ORACLE: price <= 0");
        require(upd > 0, "ORACLE: no update");
        require(block.timestamp >= upd, "ORACLE: time skew");
        require(block.timestamp - upd <= maxDelay, "ORACLE: stale");

        // casting to uint256 is safe because answer > 0 is enforced above
        // forge-lint: disable-next-line(unsafe-typecast)
        price = uint256(answer);
        updatedAt = upd;
    }
}
