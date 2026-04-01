// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.33;

// Adversarial tests for NXUSDToken — targeting the SUP-01 supply cap
// added in Hardening Round 3, plus access control and edge cases.

import {Test} from "forge-std/Test.sol";
import {NXUSDToken} from "../src/core/NXUSDToken.sol";

contract NXUSDTokenAdversarialTest is Test {
    NXUSDToken nxusd;

    address admin = address(0xA11CE);
    address minter = address(0xD00D);
    address other = address(0xBAD0);
    address user = address(0xBEEF);

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    function setUp() public {
        vm.prank(admin);
        nxusd = new NXUSDToken(admin);

        vm.prank(admin);
        nxusd.setMinter(minter, true);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SUP-01: setMaxSupply access control
    // ─────────────────────────────────────────────────────────────────────────

    function testSetMaxSupplyRevertsForNonAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, other, bytes32(0)));
        vm.prank(other);
        nxusd.setMaxSupply(1_000_000e18);
    }

    function testSetMaxSupplySucceedsForAdmin() public {
        vm.prank(admin);
        nxusd.setMaxSupply(1_000_000e18);
        assertEq(nxusd.maxSupply(), 1_000_000e18);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SUP-01: setMaxSupply guards
    // ─────────────────────────────────────────────────────────────────────────

    // Setting cap below current supply must revert.
    // Prevents governance from freezing all future minting via an undercut cap.
    function testSetMaxSupplyRevertsWhenBelowCurrentSupply() public {
        // Mint 500_000e18 first
        vm.prank(minter);
        nxusd.mint(user, 500_000e18);

        // Try to set cap below current supply
        vm.expectRevert(bytes("NXUSD: cap below current supply"));
        vm.prank(admin);
        nxusd.setMaxSupply(499_999e18);
    }

    // Setting cap exactly at current supply is allowed (no new minting permitted, but valid state)
    function testSetMaxSupplyAcceptsCapAtCurrentSupply() public {
        vm.prank(minter);
        nxusd.mint(user, 500_000e18);

        vm.prank(admin);
        nxusd.setMaxSupply(500_000e18);
        assertEq(nxusd.maxSupply(), 500_000e18);
    }

    // Zero = no cap (opt-out)
    function testSetMaxSupplyToZeroDisablesCap() public {
        vm.prank(admin);
        nxusd.setMaxSupply(1_000_000e18);

        vm.prank(admin);
        nxusd.setMaxSupply(0);
        assertEq(nxusd.maxSupply(), 0);
    }

    // Zero is allowed regardless of current supply (disabling the cap is always valid)
    function testSetMaxSupplyToZeroAllowedEvenAboveExistingSupply() public {
        vm.prank(minter);
        nxusd.mint(user, 500_000e18);

        vm.prank(admin);
        nxusd.setMaxSupply(0); // disables cap — always valid
        assertEq(nxusd.maxSupply(), 0);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SUP-01: mint() cap enforcement
    // ─────────────────────────────────────────────────────────────────────────

    // When no cap is set (maxSupply == 0), minting is uncapped — backward compatible.
    function testMintUncappedWhenMaxSupplyIsZero() public {
        assertEq(nxusd.maxSupply(), 0);

        vm.prank(minter);
        nxusd.mint(user, 999_999_999e18);

        assertEq(nxusd.balanceOf(user), 999_999_999e18);
    }

    // Mint exactly up to the cap must succeed.
    function testMintExactlyAtCapSucceeds() public {
        vm.prank(admin);
        nxusd.setMaxSupply(1_000_000e18);

        vm.prank(minter);
        nxusd.mint(user, 1_000_000e18);

        assertEq(nxusd.totalSupply(), 1_000_000e18);
    }

    // Mint that would exceed the cap by 1 must revert.
    function testMintOneUnitAboveCapReverts() public {
        vm.prank(admin);
        nxusd.setMaxSupply(1_000_000e18);

        vm.expectRevert(bytes("NXUSD: supply cap exceeded"));
        vm.prank(minter);
        nxusd.mint(user, 1_000_000e18 + 1);
    }

    // Partial mint fills to cap, then subsequent mint reverts.
    function testMintRevertsWhenCapAlreadyReached() public {
        vm.prank(admin);
        nxusd.setMaxSupply(1_000_000e18);

        vm.prank(minter);
        nxusd.mint(user, 1_000_000e18);

        vm.expectRevert(bytes("NXUSD: supply cap exceeded"));
        vm.prank(minter);
        nxusd.mint(user, 1);
    }

    // Cap applies to ALL minters, not just VaultManager.
    // A second minter granted via setMinter() is also blocked.
    function testCapEnforcedAcrossAllMinters() public {
        address minter2 = address(0xCAFE);
        vm.prank(admin);
        nxusd.setMinter(minter2, true);

        vm.prank(admin);
        nxusd.setMaxSupply(1_000_000e18);

        // minter fills half
        vm.prank(minter);
        nxusd.mint(user, 500_000e18);

        // minter2 fills the remaining half exactly
        vm.prank(minter2);
        nxusd.mint(user, 500_000e18);

        assertEq(nxusd.totalSupply(), 1_000_000e18);

        // Either minter attempting 1 more unit must revert
        vm.expectRevert(bytes("NXUSD: supply cap exceeded"));
        vm.prank(minter);
        nxusd.mint(user, 1);
    }

    // After raising the cap, further minting is allowed up to the new limit.
    function testMintAllowedAfterCapRaised() public {
        vm.prank(admin);
        nxusd.setMaxSupply(500_000e18);

        vm.prank(minter);
        nxusd.mint(user, 500_000e18);

        vm.expectRevert(bytes("NXUSD: supply cap exceeded"));
        vm.prank(minter);
        nxusd.mint(user, 1);

        // Governance raises cap
        vm.prank(admin);
        nxusd.setMaxSupply(1_000_000e18);

        vm.prank(minter);
        nxusd.mint(user, 500_000e18);

        assertEq(nxusd.totalSupply(), 1_000_000e18);
    }

    // Removing the cap (setting to 0) allows unlimited minting again.
    function testMintUnlimitedAfterCapRemoved() public {
        vm.prank(admin);
        nxusd.setMaxSupply(500_000e18);

        vm.prank(minter);
        nxusd.mint(user, 500_000e18);

        // Disable cap
        vm.prank(admin);
        nxusd.setMaxSupply(0);

        // Now can mint freely
        vm.prank(minter);
        nxusd.mint(user, 999_999_999e18);
    }
}
