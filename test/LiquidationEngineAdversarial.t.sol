// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.33;

// Adversarial test suite for LiquidationEngine.
// Targets untested branches identified in the forge coverage baseline (2026-03-21).
// Branch coverage before: 46.88% (15/32). Goal: materially above 70%.

import {Test} from "forge-std/Test.sol";

import {NXUSDToken}         from "../src/core/NXUSDToken.sol";
import {OracleModule}       from "../src/oracle/OracleModule.sol";
import {VaultManager}       from "../src/vault/VaultManager.sol";
import {LiquidationEngine}  from "../src/vault/LiquidationEngine.sol";

import {MockERC20}        from "./mocks/MockERC20.sol";
import {MockAggregatorV3} from "./mocks/MockAggregatorV3.sol";

contract LiquidationEngineAdversarialTest is Test {
    address admin   = address(0xA11CE);
    address user    = address(0xD00D);
    address keeper  = address(0xBEEF);
    address other   = address(0xBAD0);

    MockERC20        weth;
    NXUSDToken       nxusd;
    MockAggregatorV3 feed;
    OracleModule     oracle;
    VaultManager     vault;
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
        vault = new VaultManager(
            admin, address(weth), address(nxusd), address(oracle), 15000, 13000, 1 hours
        );

        vm.prank(admin);
        liq = new LiquidationEngine(admin, address(nxusd), address(vault), 5000);

        vm.prank(admin);
        nxusd.setMinter(address(vault), true);

        vm.prank(admin);
        nxusd.setBurner(address(vault), true);

        bytes32 vaultKeeperRole = vault.KEEPER_ROLE(); // read before prank
        vm.prank(admin);
        vault.grantRole(vaultKeeperRole, address(liq));

        bytes32 liqKeeperRole = liq.KEEPER_ROLE(); // read before prank
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
    // Constructor guards
    // ─────────────────────────────────────────────────────────────────────────

    function testConstructorRevertsAdminZero() public {
        vm.expectRevert(bytes("LIQ: admin is zero"));
        new LiquidationEngine(address(0), address(nxusd), address(vault), 5000);
    }

    function testConstructorRevertsNxusdZero() public {
        vm.expectRevert(bytes("LIQ: nxusd is zero"));
        new LiquidationEngine(admin, address(0), address(vault), 5000);
    }

    function testConstructorRevertsVaultZero() public {
        vm.expectRevert(bytes("LIQ: vault is zero"));
        new LiquidationEngine(admin, address(nxusd), address(0), 5000);
    }

    function testConstructorRevertsCloseFactorZero() public {
        vm.expectRevert(bytes("LIQ: close factor is zero"));
        new LiquidationEngine(admin, address(nxusd), address(vault), 0);
    }

    function testConstructorRevertsCloseFactorAbove100Pct() public {
        vm.expectRevert(bytes("LIQ: close factor > 100%"));
        new LiquidationEngine(admin, address(nxusd), address(vault), 10001);
    }

    // Constructor accepts exactly 100% close factor (boundary value)
    function testConstructorAcceptsExact100PctCloseFactor() public {
        LiquidationEngine eng = new LiquidationEngine(admin, address(nxusd), address(vault), 10000);
        assertEq(eng.closeFactorBps(), 10000);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // setVault
    // ─────────────────────────────────────────────────────────────────────────

    function testSetVaultRevertsOnZeroAddress() public {
        vm.expectRevert(bytes("LIQ: vault is zero"));
        vm.prank(admin);
        liq.setVault(address(0));
    }

    function testSetVaultRevertsForNonAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, other, bytes32(0))
        );
        vm.prank(other);
        liq.setVault(address(vault));
    }

    function testSetVaultUpdatesVault() public {
        address newVault = address(0x1234);
        vm.prank(admin);
        liq.setVault(newVault);
        assertEq(address(liq.vault()), newVault);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // setCloseFactor
    // ─────────────────────────────────────────────────────────────────────────

    function testSetCloseFactorRevertsOnZero() public {
        vm.expectRevert(bytes("LIQ: close factor is zero"));
        vm.prank(admin);
        liq.setCloseFactor(0);
    }

    function testSetCloseFactorRevertsAbove100Pct() public {
        vm.expectRevert(bytes("LIQ: close factor > 100%"));
        vm.prank(admin);
        liq.setCloseFactor(10001);
    }

    function testSetCloseFactorRevertsForNonAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, other, bytes32(0))
        );
        vm.prank(other);
        liq.setCloseFactor(7000);
    }

    function testSetCloseFactorUpdatesValue() public {
        vm.prank(admin);
        liq.setCloseFactor(7500);
        assertEq(liq.closeFactorBps(), 7500);
    }

    // Exactly 100% is the valid boundary
    function testSetCloseFactorAcceptsExact100Pct() public {
        vm.prank(admin);
        liq.setCloseFactor(10000);
        assertEq(liq.closeFactorBps(), 10000);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // executeLiquidation input guards
    // ─────────────────────────────────────────────────────────────────────────

    function testExecuteLiquidationRevertsOnAccountZero() public {
        _openUnsafeVault();
        _mintNxusdForKeeper(1000e18);

        vm.expectRevert(bytes("LIQ: account is zero"));
        vm.prank(keeper);
        liq.executeLiquidation(address(0), 1000e18);
    }

    function testExecuteLiquidationRevertsOnRepayZero() public {
        _openUnsafeVault();
        _mintNxusdForKeeper(1000e18);

        vm.expectRevert(bytes("LIQ: repay is zero"));
        vm.prank(keeper);
        liq.executeLiquidation(user, 0);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Close factor boundary precision
    // debt = 2000e18, closeFactorBps = 5000 → maxRepay = 1000e18
    //   1000e18     → exact boundary, should succeed
    //   1000e18 + 1 → one wei over, should revert
    // ─────────────────────────────────────────────────────────────────────────

    function testExecuteLiquidationAtExactCloseFactorBoundarySucceeds() public {
        _openUnsafeVault();
        _mintNxusdForKeeper(1000e18);

        vm.prank(keeper);
        uint256 seized = liq.executeLiquidation(user, 1000e18);

        assertEq(vault.debtOf(user), 1000e18, "half of debt should remain");
        assertGt(seized, 0);
    }

    function testExecuteLiquidationOneWeiAboveCloseFactorReverts() public {
        _openUnsafeVault();
        _mintNxusdForKeeper(1000e18 + 1);

        vm.expectRevert(bytes("LIQ: exceeds close factor"));
        vm.prank(keeper);
        liq.executeLiquidation(user, 1000e18 + 1);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Full liquidation at 100% close factor
    // ─────────────────────────────────────────────────────────────────────────

    function testFullLiquidationWith100PctCloseFactor() public {
        _openUnsafeVault();

        vm.prank(admin);
        liq.setCloseFactor(10000);

        _mintNxusdForKeeper(2000e18);

        vm.prank(keeper);
        uint256 seized = liq.executeLiquidation(user, 2000e18);

        assertEq(vault.debtOf(user), 0, "all debt should be cleared");
        assertGt(seized, 0);
        assertEq(weth.balanceOf(keeper), seized);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Pause blocks executeLiquidation (already in LiquidationPause.t.sol;
    // confirming the non-paused happy path increments correctly here)
    // ─────────────────────────────────────────────────────────────────────────

    function testExecuteLiquidationUpdatesDebtAfterExecution() public {
        _openUnsafeVault();
        _mintNxusdForKeeper(500e18);

        uint256 debtBefore = vault.debtOf(user);

        vm.prank(keeper);
        liq.executeLiquidation(user, 500e18);

        assertEq(vault.debtOf(user), debtBefore - 500e18);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Keeper NXUSD flow: transferFrom keeper → transfer to account → vault burns
    // Validate keeper balance decreases and debt decreases
    // ─────────────────────────────────────────────────────────────────────────

    function testExecuteLiquidationNxusdFlowIsCorrect() public {
        _openUnsafeVault();

        uint256 repay = 800e18;
        _mintNxusdForKeeper(repay);

        uint256 keeperBalBefore = nxusd.balanceOf(keeper);

        vm.prank(keeper);
        liq.executeLiquidation(user, repay);

        // Keeper paid repay NXUSD
        assertEq(nxusd.balanceOf(keeper), keeperBalBefore - repay);

        // Debt reduced
        assertEq(vault.debtOf(user), 2000e18 - repay);
    }
}
