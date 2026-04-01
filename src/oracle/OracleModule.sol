// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

interface IAggregatorV3 {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract OracleModule is AccessControl {
    /// @notice Hard upper bound on maxDelay. Prevents disabling freshness checks
    ///         via extreme values (e.g. type(uint256).max). 7 days is generous
    ///         enough for irregular testnet feeds while blocking the attack vector.
    uint256 public constant MAX_DELAY = 7 days;

    /// @notice Grace period enforced after Arbitrum sequencer restart before prices
    ///         are accepted. Prevents liquidation raids on positions that could not
    ///         defend themselves during sequencer downtime.
    ///         Chainlink recommendation for Arbitrum L2 deployments: minimum 3600s.
    uint256 public constant SEQ_GRACE_PERIOD = 3600;

    IAggregatorV3 public feed;
    uint256 public maxDelay;

    /// @notice Chainlink L2 sequencer uptime feed. address(0) = check disabled.
    ///         Must be set to the Arbitrum sequencer uptime feed on Arbitrum One:
    ///         0xFdB631F5EE196F0ed6FAa767959853A9F217697D
    ///         Leave as address(0) on non-Arbitrum networks or in testing.
    IAggregatorV3 public sequencerFeed;

    event OracleFeedSet(address indexed feed, address indexed by);
    event OracleMaxDelaySet(uint256 maxDelay, address indexed by);
    event SequencerFeedSet(address indexed feed, address indexed by);

    /// @param admin           Address granted DEFAULT_ADMIN_ROLE.
    /// @param feed_           Chainlink price feed address.
    /// @param maxDelay_       Maximum accepted age of price data (seconds).
    /// @param sequencerFeed_  Chainlink L2 sequencer uptime feed. address(0) disables
    ///                        the check (use on non-Arbitrum networks or in tests).
    constructor(address admin, address feed_, uint256 maxDelay_, address sequencerFeed_) {
        require(admin != address(0), "ORACLE: admin is zero");
        require(feed_ != address(0), "ORACLE: feed is zero");
        require(maxDelay_ > 0, "ORACLE: maxDelay is zero");
        require(maxDelay_ <= MAX_DELAY, "ORACLE: maxDelay too large");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        feed = IAggregatorV3(feed_);
        maxDelay = maxDelay_;

        // sequencerFeed_ == address(0) is valid and disables the uptime check.
        sequencerFeed = IAggregatorV3(sequencerFeed_);

        emit OracleFeedSet(feed_, admin);
        emit OracleMaxDelaySet(maxDelay_, admin);
        emit SequencerFeedSet(sequencerFeed_, admin);
    }

    function setFeed(address feed_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(feed_ != address(0), "ORACLE: feed is zero");
        // Smoke-check: verify the feed is callable and currently returns a positive answer.
        // Catches mis-addressed feeds and contracts that don't implement IAggregatorV3
        // at commit time rather than at next vault operation.
        // Note: a feed that passes here could still return invalid data later;
        // getPrice() enforces all freshness and sign checks at usage time.
        (, int256 answer,,,) = IAggregatorV3(feed_).latestRoundData();
        require(answer > 0, "ORACLE: new feed answer not positive");
        feed = IAggregatorV3(feed_);
        emit OracleFeedSet(feed_, msg.sender);
    }

    function setMaxDelay(uint256 maxDelay_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(maxDelay_ > 0, "ORACLE: maxDelay is zero");
        require(maxDelay_ <= MAX_DELAY, "ORACLE: maxDelay too large");
        maxDelay = maxDelay_;
        emit OracleMaxDelaySet(maxDelay_, msg.sender);
    }

    /// @notice Set or clear the Arbitrum L2 sequencer uptime feed.
    ///         Pass address(0) to disable the check (non-Arbitrum networks).
    ///         Pass the Chainlink sequencer uptime feed address to enable it.
    function setSequencerFeed(address sequencerFeed_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        sequencerFeed = IAggregatorV3(sequencerFeed_);
        emit SequencerFeedSet(sequencerFeed_, msg.sender);
    }

    /// @notice Returns the current price from the configured Chainlink feed.
    ///
    ///         H-03 FIX: When sequencerFeed is configured, checks the Chainlink
    ///         Arbitrum sequencer uptime feed before accepting any price data:
    ///           - answer == 0: sequencer is up (Chainlink convention)
    ///           - answer != 0: sequencer is down → revert
    ///           - SEQ_GRACE_PERIOD must have elapsed since last sequencer restart
    ///             before prices are accepted, preventing liquidation raids on positions
    ///             that could not be defended during downtime.
    function getPrice() external view returns (uint256 price, uint256 updatedAt, uint8 decimals) {
        // ── L2 sequencer uptime check ─────────────────────────────────────────
        // Only executed when sequencerFeed is configured (non-zero).
        // Chainlink L2 sequencer uptime feed convention:
        //   latestRoundData().answer == 0 → sequencer is UP
        //   latestRoundData().answer != 0 → sequencer is DOWN
        //   latestRoundData().startedAt   → timestamp of last state change
        //
        // After a restart (answer flips to 0), startedAt records the restart time.
        // The grace period ensures that at least SEQ_GRACE_PERIOD seconds have passed
        // since restart before any price-sensitive operation is allowed, giving users
        // time to respond to price changes that occurred during downtime.
        if (address(sequencerFeed) != address(0)) {
            (, int256 seqAnswer, uint256 seqStartedAt,,) = sequencerFeed.latestRoundData();
            require(seqAnswer == 0, "ORACLE: sequencer down");
            require(block.timestamp - seqStartedAt >= SEQ_GRACE_PERIOD, "ORACLE: sequencer grace period");
        }

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
