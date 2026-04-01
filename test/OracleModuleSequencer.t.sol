// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.33;

// H-03 FIX VERIFICATION — Chainlink L2 Sequencer Uptime Check
//
// Verifies that OracleModule.getPrice() enforces the Arbitrum sequencer uptime
// check and post-restart grace period when a sequencerFeed is configured.
//
// MockAggregatorV3 is repurposed as the sequencer feed mock.
// Chainlink sequencer feed convention:
//   answer == 0  → sequencer is UP
//   answer != 0  → sequencer is DOWN (typically 1)
//   startedAt    → timestamp of last state change (restart time when answer == 0)

import {Test} from "forge-std/Test.sol";
import {OracleModule} from "../src/oracle/OracleModule.sol";
import {MockAggregatorV3} from "./mocks/MockAggregatorV3.sol";

contract OracleModuleSequencerTest is Test {
    OracleModule oracle;
    MockAggregatorV3 feed;
    MockAggregatorV3 seqFeed;

    address admin = address(0xA11CE);

    uint256 constant GRACE = 3600; // OracleModule.SEQ_GRACE_PERIOD

    function setUp() public {
        // Warp to a timestamp large enough to avoid underflow when subtracting
        // multiples of GRACE (3600s). Foundry's default block.timestamp is 1.
        vm.warp(100_000);

        // Price feed: ETH/USD at $2000, 8 decimals
        feed = new MockAggregatorV3(8);
        feed.setRoundData(2000_00000000, block.timestamp);

        // Sequencer feed: starts UP (answer=0), started well before now
        seqFeed = new MockAggregatorV3(0); // decimals unused for sequencer feed
        // Sequencer has been up for > GRACE_PERIOD: startedAt = now - 2h
        // MockAggregatorV3.setRoundData sets startedAt = updatedAt_
        seqFeed.setRoundData(0, block.timestamp - 2 * GRACE);

        vm.prank(admin);
        oracle = new OracleModule(admin, address(feed), 1 hours, address(seqFeed));
    }

    // ── Test 1: price fetch reverts when sequencer is down ───────────────────

    function testGetPriceRevertsWhenSequencerDown() public {
        // Set sequencer feed to DOWN (answer = 1)
        seqFeed.setRoundData(1, block.timestamp);

        vm.expectRevert(bytes("ORACLE: sequencer down"));
        oracle.getPrice();
    }

    // ── Test 2: price fetch reverts during grace period after restart ─────────

    function testGetPriceRevertsInGracePeriodAfterRestart() public {
        // Simulate restart: sequencer comes back up (answer=0) right now.
        // startedAt = block.timestamp → elapsed = 0 < GRACE_PERIOD → reject.
        seqFeed.setRoundData(0, block.timestamp);

        vm.expectRevert(bytes("ORACLE: sequencer grace period"));
        oracle.getPrice();
    }

    function testGetPriceRevertsOneSecondBeforeGracePeriodExpires() public {
        uint256 restartTime = block.timestamp - (GRACE - 1); // 1 second short
        seqFeed.setRoundData(0, restartTime);

        vm.expectRevert(bytes("ORACLE: sequencer grace period"));
        oracle.getPrice();
    }

    // ── Test 3: price fetch succeeds after grace period when sequencer is up ──

    function testGetPriceSucceedsAfterGracePeriod() public {
        // Sequencer has been up for exactly GRACE_PERIOD seconds.
        uint256 restartTime = block.timestamp - GRACE;
        seqFeed.setRoundData(0, restartTime);

        (uint256 price,, uint8 decimals) = oracle.getPrice();
        assertEq(price, 2000_00000000);
        assertEq(decimals, 8);
    }

    function testGetPriceSucceedsWhenSequencerUpLongBefore() public {
        // Sequencer has been up for 24 hours (normal operating state). setUp()
        // already configures this; confirm it works as expected.
        (uint256 price,,) = oracle.getPrice();
        assertEq(price, 2000_00000000);
    }

    // ── Test 4: check disabled when sequencerFeed is address(0) ──────────────

    function testGetPriceSucceedsWhenSequencerFeedNotConfigured() public {
        // Deploy a separate oracle with no sequencer feed (address(0)).
        // Even if we were to set a "down" signal somewhere, no check is performed.
        vm.prank(admin);
        OracleModule oracleNoSeq = new OracleModule(admin, address(feed), 1 hours, address(0));

        // No sequencer feed → no check → succeeds regardless.
        (uint256 price,,) = oracleNoSeq.getPrice();
        assertEq(price, 2000_00000000);
    }

    // ── setSequencerFeed admin controls ──────────────────────────────────────

    function testAdminCanClearSequencerFeed() public {
        // Clear the sequencer feed → check becomes disabled.
        vm.prank(admin);
        oracle.setSequencerFeed(address(0));

        assertEq(address(oracle.sequencerFeed()), address(0));

        // getPrice() no longer checks sequencer; works even with a "down" feed.
        seqFeed.setRoundData(1, block.timestamp); // would have triggered "down" revert
        (uint256 price,,) = oracle.getPrice(); // passes — feed is no longer registered
        assertEq(price, 2000_00000000);
    }

    function testAdminCanReplaceSequencerFeed() public {
        MockAggregatorV3 newSeqFeed = new MockAggregatorV3(0);
        newSeqFeed.setRoundData(0, block.timestamp - 2 * GRACE); // UP, past grace period

        vm.prank(admin);
        oracle.setSequencerFeed(address(newSeqFeed));

        assertEq(address(oracle.sequencerFeed()), address(newSeqFeed));

        (uint256 price,,) = oracle.getPrice();
        assertEq(price, 2000_00000000);
    }

    function testNonAdminCannotSetSequencerFeed() public {
        address attacker = address(0xBAD0);
        vm.expectRevert();
        vm.prank(attacker);
        oracle.setSequencerFeed(address(seqFeed));
    }

    // ── SEQ_GRACE_PERIOD constant ─────────────────────────────────────────────

    function testSeqGracePeriodConstantIs3600() public {
        assertEq(oracle.SEQ_GRACE_PERIOD(), 3600);
    }
}
