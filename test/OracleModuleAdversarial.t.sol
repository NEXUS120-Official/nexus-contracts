// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.33;

// Adversarial tests for OracleModule — targeting branches not covered by OracleModule.t.sol
// and validating the setFeed smoke-check hardening added in Hardening Round 2.

import {Test} from "forge-std/Test.sol";
import {OracleModule} from "../src/oracle/OracleModule.sol";
import {MockAggregatorV3} from "./mocks/MockAggregatorV3.sol";

contract OracleModuleAdversarialTest is Test {
    OracleModule oracle;
    MockAggregatorV3 feed;

    address admin = address(0xA11CE);
    address other = address(0xBAD0);

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    function setUp() public {
        feed = new MockAggregatorV3(8);
        feed.setRoundData(2000_00000000, block.timestamp);

        vm.prank(admin);
        oracle = new OracleModule(admin, address(feed), 1 hours, address(0));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor guards (OracleModule.t.sol doesn't cover these)
    // ─────────────────────────────────────────────────────────────────────────

    function testConstructorRevertsAdminZero() public {
        vm.expectRevert(bytes("ORACLE: admin is zero"));
        new OracleModule(address(0), address(feed), 1 hours, address(0));
    }

    function testConstructorRevertsFeedZero() public {
        vm.expectRevert(bytes("ORACLE: feed is zero"));
        new OracleModule(admin, address(0), 1 hours, address(0));
    }

    function testConstructorRevertsMaxDelayZero() public {
        vm.expectRevert(bytes("ORACLE: maxDelay is zero"));
        new OracleModule(admin, address(feed), 0, address(0));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // setFeed — hardened smoke-check (Hardening Round 2)
    // ─────────────────────────────────────────────────────────────────────────

    // A new feed whose answer is zero at commit time must be rejected.
    // Catches mis-addressed contracts and feeds that report invalid prices.
    function testSetFeedRevertsWhenNewFeedAnswerIsZero() public {
        MockAggregatorV3 badFeed = new MockAggregatorV3(8);
        // No setRoundData call: answer defaults to 0

        vm.expectRevert(bytes("ORACLE: new feed answer not positive"));
        vm.prank(admin);
        oracle.setFeed(address(badFeed));
    }

    function testSetFeedRevertsWhenNewFeedAnswerIsNegative() public {
        MockAggregatorV3 badFeed = new MockAggregatorV3(8);
        badFeed.setRoundData(-1, block.timestamp);

        vm.expectRevert(bytes("ORACLE: new feed answer not positive"));
        vm.prank(admin);
        oracle.setFeed(address(badFeed));
    }

    // setFeed: zero address → revert (pre-existing check, covered here for completeness)
    function testSetFeedRevertsOnZeroAddress() public {
        vm.expectRevert(bytes("ORACLE: feed is zero"));
        vm.prank(admin);
        oracle.setFeed(address(0));
    }

    // setFeed: valid feed with positive answer → succeeds and updates storage
    function testSetFeedSucceedsWithValidAnswer() public {
        MockAggregatorV3 newFeed = new MockAggregatorV3(8);
        newFeed.setRoundData(3000_00000000, block.timestamp);

        vm.prank(admin);
        oracle.setFeed(address(newFeed));

        assertEq(address(oracle.feed()), address(newFeed));
    }

    // After a valid setFeed, getPrice() returns the new feed's data
    function testSetFeedAndGetPriceReturnsNewFeedData() public {
        MockAggregatorV3 newFeed = new MockAggregatorV3(8);
        newFeed.setRoundData(3000_00000000, block.timestamp);

        vm.prank(admin);
        oracle.setFeed(address(newFeed));

        (uint256 price,,) = oracle.getPrice();
        assertEq(price, 3000_00000000);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // setMaxDelay — branches not covered in OracleModule.t.sol
    // ─────────────────────────────────────────────────────────────────────────

    function testSetMaxDelayRevertsOnZero() public {
        vm.expectRevert(bytes("ORACLE: maxDelay is zero"));
        vm.prank(admin);
        oracle.setMaxDelay(0);
    }

    function testSetMaxDelayUpdatesValue() public {
        vm.prank(admin);
        oracle.setMaxDelay(2 hours);
        assertEq(oracle.maxDelay(), 2 hours);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ORC-03: setMaxDelay upper bound (Hardening Round 3)
    // MAX_DELAY = 7 days. Setting type(uint256).max would silently disable
    // freshness checks — the upper bound prevents this attack vector.
    // ─────────────────────────────────────────────────────────────────────────

    function testSetMaxDelayRevertsWhenTooLarge() public {
        vm.expectRevert(bytes("ORACLE: maxDelay too large"));
        vm.prank(admin);
        oracle.setMaxDelay(7 days + 1);
    }

    // type(uint256).max is the canonical attack value — also rejected
    function testSetMaxDelayRevertsForMaxUint() public {
        vm.expectRevert(bytes("ORACLE: maxDelay too large"));
        vm.prank(admin);
        oracle.setMaxDelay(type(uint256).max);
    }

    // Exactly MAX_DELAY (7 days) must be accepted
    function testSetMaxDelayAcceptsMaxAllowed() public {
        vm.prank(admin);
        oracle.setMaxDelay(7 days);
        assertEq(oracle.maxDelay(), 7 days);
    }

    // Constructor with maxDelay > MAX_DELAY must revert
    function testConstructorRevertsMaxDelayTooLarge() public {
        vm.expectRevert(bytes("ORACLE: maxDelay too large"));
        new OracleModule(admin, address(feed), 7 days + 1, address(0));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getPrice: no-update branch (updatedAt == 0)
    // ─────────────────────────────────────────────────────────────────────────

    function testGetPriceRevertsOnZeroUpdatedAt() public {
        // MockAggregatorV3 with valid answer but updatedAt = 0
        MockAggregatorV3 noTimeFeed = new MockAggregatorV3(8);
        noTimeFeed.setRoundData(2000_00000000, 0);

        vm.prank(admin);
        // setFeed will call latestRoundData() — answer = 2000e8 > 0, passes smoke check
        oracle.setFeed(address(noTimeFeed));

        vm.expectRevert(bytes("ORACLE: no update"));
        oracle.getPrice();
    }

    // getPrice: future timestamp (updatedAt > block.timestamp)
    function testGetPriceRevertsOnFutureTimestamp() public {
        MockAggregatorV3 futureFeed = new MockAggregatorV3(8);
        // At setFeed time: updatedAt = block.timestamp (passes smoke check)
        futureFeed.setRoundData(2000_00000000, block.timestamp);

        vm.prank(admin);
        oracle.setFeed(address(futureFeed));

        // Now advance the feed's updatedAt to a future timestamp
        futureFeed.setRoundData(2000_00000000, block.timestamp + 100);

        vm.expectRevert(bytes("ORACLE: time skew"));
        oracle.getPrice();
    }
}
