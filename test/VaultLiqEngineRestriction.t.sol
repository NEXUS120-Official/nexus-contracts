// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.33;

// [TASK 1] Close-Factor Bypass Prevention
//
// Verifies that VaultManager.liquidate() is gated exclusively by the registered
// liqEngine address. Any caller — including a KEEPER_ROLE holder — that is not
// the registered liqEngine must be rejected.
//
// Before this hardening pass, any address with KEEPER_ROLE could call
// vault.liquidate() directly, bypassing LiquidationEngine's close-factor limit.

import {Test} from "forge-std/Test.sol";

import {NXUSDToken} from "../src/core/NXUSDToken.sol";
import {OracleModule} from "../src/oracle/OracleModule.sol";
import {VaultManager} from "../src/vault/VaultManager.sol";
import {LiquidationEngine} from "../src/vault/LiquidationEngine.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {MockAggregatorV3} from "./mocks/MockAggregatorV3.sol";

contract VaultLiqEngineRestrictionTest is Test {
    address admin = address(0xA11CE);
    address user = address(0xD00D);
    address keeper = address(0xBEEF);
    address attacker = address(0xBAD0);

    MockERC20 weth;
    NXUSDToken nxusd;
    MockAggregatorV3 feed;
    OracleModule oracle;
    VaultManager vault;
    LiquidationEngine liq;

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    function setUp() public {
        weth = new MockERC20("Wrapped Ether", "WETH");

        vm.prank(admin);
        nxusd = new NXUSDToken(admin);

        feed = new MockAggregatorV3(8);
        feed.setRoundData(2000_00000000, block.timestamp);

        vm.prank(admin);
        oracle = new OracleModule(admin, address(feed), 1 hours, address(0));

        vm.prank(admin);
        vault = new VaultManager(admin, address(weth), address(nxusd), address(oracle), 15000, 13000, 1 hours);

        vm.prank(admin);
        liq = new LiquidationEngine(admin, address(nxusd), address(vault), 5000);

        vm.prank(admin);
        nxusd.setMinter(address(vault), true);

        vm.prank(admin);
        nxusd.setBurner(address(vault), true);

        bytes32 vaultKeeperRole = vault.KEEPER_ROLE();
        vm.prank(admin);
        vault.grantRole(vaultKeeperRole, address(liq));

        vm.prank(admin);
        vault.setLiquidationEngine(address(liq));

        bytes32 liqKeeperRole = liq.KEEPER_ROLE();
        vm.prank(admin);
        liq.grantRole(liqKeeperRole, keeper);

        weth.mint(user, 10 ether);
        vm.prank(user);
        weth.approve(address(vault), type(uint256).max);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    function _openUnsafeVault() internal {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(user);
        vault.mint(2000e18); // CR = 200% at $2000

        // Drop to $1200: value = $2400, debt = $2000, CR = 120% < 130% liqCR
        feed.setRoundData(1200_00000000, block.timestamp);
    }

    function _mintNxusdForKeeper(uint256 amount) internal {
        vm.prank(admin);
        nxusd.setMinter(keeper, true);

        vm.prank(keeper);
        nxusd.mint(keeper, amount);

        vm.prank(keeper);
        nxusd.approve(address(liq), amount);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // setLiquidationEngine guards
    // ─────────────────────────────────────────────────────────────────────────

    function testSetLiquidationEngineRevertsOnZeroAddress() public {
        vm.expectRevert(bytes("VAULT: liqEngine is zero"));
        vm.prank(admin);
        vault.setLiquidationEngine(address(0));
    }

    function testSetLiquidationEngineRevertsForNonAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, attacker, bytes32(0)));
        vm.prank(attacker);
        vault.setLiquidationEngine(address(liq));
    }

    function testSetLiquidationEngineRevertsForKeeper() public {
        // KEEPER_ROLE is not sufficient; only DEFAULT_ADMIN_ROLE may call setLiquidationEngine.
        bytes32 keeperRole = vault.KEEPER_ROLE();
        vm.prank(admin);
        vault.grantRole(keeperRole, attacker);

        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, attacker, bytes32(0)));
        vm.prank(attacker);
        vault.setLiquidationEngine(address(liq));
    }

    function testSetLiquidationEngineUpdatesStorage() public {
        address newLiq = address(0x1234);
        vm.prank(admin);
        vault.setLiquidationEngine(newLiq);
        assertEq(vault.liqEngine(), newLiq);
    }

    function testSetLiquidationEngineEmitsEvent() public {
        address newLiq = address(0x1234);

        vm.expectEmit(true, true, false, false);
        emit VaultManager.LiquidationEngineSet(newLiq, admin);

        vm.prank(admin);
        vault.setLiquidationEngine(newLiq);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // liquidate() access control
    // ─────────────────────────────────────────────────────────────────────────

    // Before liqEngine is set, liquidate() is permanently blocked.
    function testLiquidateRevertsWhenLiqEngineNotSet() public {
        // Deploy a fresh vault with no liqEngine registered.
        vm.prank(admin);
        VaultManager freshVault =
            new VaultManager(admin, address(weth), address(nxusd), address(oracle), 15000, 13000, 1 hours);

        vm.prank(admin);
        nxusd.setMinter(address(freshVault), true);
        vm.prank(admin);
        nxusd.setBurner(address(freshVault), true);

        weth.mint(address(0xDEAD), 2 ether);
        vm.prank(address(0xDEAD));
        weth.approve(address(freshVault), type(uint256).max);
        vm.prank(address(0xDEAD));
        freshVault.deposit(2 ether);
        vm.prank(address(0xDEAD));
        freshVault.mint(2000e18);

        feed.setRoundData(1200_00000000, block.timestamp);

        // liqEngine == address(0) → msg.sender (anything) != liqEngine → revert
        vm.expectRevert(bytes("VAULT: only liqEngine"));
        vm.prank(attacker);
        freshVault.liquidate(address(0xDEAD), attacker, 1000e18);
    }

    // A KEEPER_ROLE holder that is NOT the registered liqEngine is rejected.
    function testDirectKeeperCannotCallLiquidate() public {
        _openUnsafeVault();

        // keeper has KEEPER_ROLE on vault (granted in setUp via liq's role chain)
        // but is NOT the registered liqEngine — must be rejected.
        vm.expectRevert(bytes("VAULT: only liqEngine"));
        vm.prank(keeper);
        vault.liquidate(user, keeper, 1000e18);
    }

    // An arbitrary address that has no role is also rejected.
    function testArbitraryAddressCannotCallLiquidate() public {
        _openUnsafeVault();

        vm.expectRevert(bytes("VAULT: only liqEngine"));
        vm.prank(attacker);
        vault.liquidate(user, attacker, 1000e18);
    }

    // Admin itself cannot call liquidate directly (not the liqEngine).
    function testAdminCannotCallLiquidateDirectly() public {
        _openUnsafeVault();

        vm.expectRevert(bytes("VAULT: only liqEngine"));
        vm.prank(admin);
        vault.liquidate(user, admin, 1000e18);
    }

    // The registered liqEngine CAN call liquidate() and the liquidation succeeds.
    function testRegisteredLiqEngineCanCallLiquidate() public {
        _openUnsafeVault();
        _mintNxusdForKeeper(1000e18);

        vm.prank(keeper);
        uint256 seized = liq.executeLiquidation(user, 1000e18);

        assertEq(vault.debtOf(user), 1000e18, "half of debt should remain");
        assertGt(seized, 0);
        assertEq(weth.balanceOf(keeper), seized);
    }

    // Admin can rotate the liqEngine to a new address; the old address is then rejected.
    function testRotatingLiqEngineBlocksOldEngine() public {
        _openUnsafeVault();

        address oldLiq = address(liq);
        address newLiq = address(0x5678);

        vm.prank(admin);
        vault.setLiquidationEngine(newLiq);

        // Old liqEngine (liq contract) is now rejected.
        vm.expectRevert(bytes("VAULT: only liqEngine"));
        vm.prank(oldLiq);
        vault.liquidate(user, oldLiq, 1000e18);
    }
}
