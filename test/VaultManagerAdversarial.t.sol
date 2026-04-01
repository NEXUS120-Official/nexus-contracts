// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.33;

// Adversarial test suite for VaultManager.
// Targets untested branches identified in the forge coverage baseline (2026-03-21).
// Branch coverage before: 40.74% (33/81).  Goal: materially above 60%.

import {Test} from "forge-std/Test.sol";

import {NXUSDToken} from "../src/core/NXUSDToken.sol";
import {OracleModule} from "../src/oracle/OracleModule.sol";
import {VaultManager} from "../src/vault/VaultManager.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {MockAggregatorV3} from "./mocks/MockAggregatorV3.sol";
import {MockOracle} from "./mocks/MockOracle.sol";

contract VaultManagerAdversarialTest is Test {
    address admin = address(0xA11CE);
    address user = address(0xD00D);
    address other = address(0xBAD0);

    MockERC20 weth;
    NXUSDToken nxusd;
    MockAggregatorV3 feed;
    OracleModule oracle;
    VaultManager vault;

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
        nxusd.setMinter(address(vault), true);

        vm.prank(admin);
        nxusd.setBurner(address(vault), true);

        weth.mint(user, 100 ether);

        vm.prank(user);
        weth.approve(address(vault), type(uint256).max);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor guards
    // ─────────────────────────────────────────────────────────────────────────

    function testConstructorRevertsAdminZero() public {
        vm.expectRevert(bytes("VAULT: admin is zero"));
        new VaultManager(address(0), address(weth), address(nxusd), address(oracle), 15000, 13000, 1 hours);
    }

    function testConstructorRevertsCollateralZero() public {
        vm.expectRevert(bytes("VAULT: collateral is zero"));
        new VaultManager(admin, address(0), address(nxusd), address(oracle), 15000, 13000, 1 hours);
    }

    function testConstructorRevertsNxusdZero() public {
        vm.expectRevert(bytes("VAULT: nxusd is zero"));
        new VaultManager(admin, address(weth), address(0), address(oracle), 15000, 13000, 1 hours);
    }

    function testConstructorRevertsOracleZero() public {
        vm.expectRevert(bytes("VAULT: oracle is zero"));
        new VaultManager(admin, address(weth), address(nxusd), address(0), 15000, 13000, 1 hours);
    }

    function testConstructorRevertsMinCrBelow100Pct() public {
        vm.expectRevert(bytes("VAULT: minCR < 100%"));
        new VaultManager(admin, address(weth), address(nxusd), address(oracle), 9999, 9000, 1 hours);
    }

    function testConstructorRevertsLiqCrBelow100Pct() public {
        vm.expectRevert(bytes("VAULT: liqCR < 100%"));
        new VaultManager(admin, address(weth), address(nxusd), address(oracle), 15000, 9999, 1 hours);
    }

    function testConstructorRevertsMinCrBelowLiqCr() public {
        vm.expectRevert(bytes("VAULT: minCR < liqCR"));
        new VaultManager(admin, address(weth), address(nxusd), address(oracle), 13000, 15000, 1 hours);
    }

    function testConstructorRevertsMaxDelayZero() public {
        vm.expectRevert(bytes("VAULT: maxDelay is zero"));
        new VaultManager(admin, address(weth), address(nxusd), address(oracle), 15000, 13000, 0);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // setOracle
    // ─────────────────────────────────────────────────────────────────────────

    function testSetOracleRevertsOnZeroAddress() public {
        vm.expectRevert(bytes("VAULT: oracle is zero"));
        vm.prank(admin);
        vault.setOracle(address(0));
    }

    function testSetOracleRevertsForNonAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, other, bytes32(0)));
        vm.prank(other);
        vault.setOracle(address(oracle));
    }

    function testSetOracleUpdatesOracle() public {
        MockOracle newOracle = new MockOracle();
        vm.prank(admin);
        vault.setOracle(address(newOracle));
        assertEq(address(vault.oracle()), address(newOracle));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ORC-04: setOracle smoke-check (Hardening Round 3)
    // Equivalent protection to OracleModule.setFeed() hardened in v1.2.
    // ─────────────────────────────────────────────────────────────────────────

    // Calling getPrice() on an EOA returns empty bytes; ABI-decoding (uint256,uint256,uint8)
    // from empty data panics → caught by vm.expectRevert() without arguments.
    function testSetOracleRevertsForNonContract() public {
        address eoa = address(0xBEEF);
        vm.expectRevert();
        vm.prank(admin);
        vault.setOracle(eoa);
    }

    // A contract that implements IOracleModule but reports price=0 must be rejected.
    // Prevents installing a permanently-broken oracle that would lock the vault.
    function testSetOracleRevertsForZeroPriceOracle() public {
        MockOracle badOracle = new MockOracle();
        badOracle.setPrice(0);

        vm.expectRevert(bytes("VAULT: new oracle zero price"));
        vm.prank(admin);
        vault.setOracle(address(badOracle));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // setRatios
    // ─────────────────────────────────────────────────────────────────────────

    function testSetRatiosRevertsMinCrBelow100Pct() public {
        vm.expectRevert(bytes("VAULT: minCR < 100%"));
        vm.prank(admin);
        vault.setRatios(9999, 9000);
    }

    function testSetRatiosRevertsLiqCrBelow100Pct() public {
        vm.expectRevert(bytes("VAULT: liqCR < 100%"));
        vm.prank(admin);
        vault.setRatios(15000, 9999);
    }

    function testSetRatiosRevertsWhenMinCrBelowLiqCr() public {
        vm.expectRevert(bytes("VAULT: minCR < liqCR"));
        vm.prank(admin);
        vault.setRatios(12000, 13000);
    }

    function testSetRatiosRevertsForNonAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, other, bytes32(0)));
        vm.prank(other);
        vault.setRatios(15000, 13000);
    }

    function testSetRatiosUpdatesValues() public {
        vm.prank(admin);
        vault.setRatios(20000, 15000);
        assertEq(vault.minCollateralRatioBps(), 20000);
        assertEq(vault.liquidationRatioBps(), 15000);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // setMaxDelay
    // ─────────────────────────────────────────────────────────────────────────

    function testSetMaxDelayRevertsOnZero() public {
        vm.expectRevert(bytes("VAULT: maxDelay is zero"));
        vm.prank(admin);
        vault.setMaxDelay(0);
    }

    function testSetMaxDelayRevertsForNonAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, other, bytes32(0)));
        vm.prank(other);
        vault.setMaxDelay(2 hours);
    }

    function testSetMaxDelayUpdatesValue() public {
        vm.prank(admin);
        vault.setMaxDelay(2 hours);
        assertEq(vault.maxDelay(), 2 hours);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ORC-03: setMaxDelay upper bound (Hardening Round 3)
    // ─────────────────────────────────────────────────────────────────────────

    function testSetMaxDelayRevertsWhenTooLarge() public {
        vm.expectRevert(bytes("VAULT: maxDelay too large"));
        vm.prank(admin);
        vault.setMaxDelay(7 days + 1);
    }

    function testSetMaxDelayRevertsForMaxUint() public {
        vm.expectRevert(bytes("VAULT: maxDelay too large"));
        vm.prank(admin);
        vault.setMaxDelay(type(uint256).max);
    }

    function testSetMaxDelayAcceptsMaxAllowed() public {
        vm.prank(admin);
        vault.setMaxDelay(7 days);
        assertEq(vault.maxDelay(), 7 days);
    }

    function testConstructorRevertsMaxDelayTooLarge() public {
        vm.expectRevert(bytes("VAULT: maxDelay too large"));
        new VaultManager(admin, address(weth), address(nxusd), address(oracle), 15000, 13000, 7 days + 1);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // deposit zero-input guard
    // ─────────────────────────────────────────────────────────────────────────

    function testDepositRevertsOnZeroAmount() public {
        vm.expectRevert(bytes("VAULT: amount is zero"));
        vm.prank(user);
        vault.deposit(0);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // withdraw input guards
    // ─────────────────────────────────────────────────────────────────────────

    function testWithdrawRevertsOnZeroAmount() public {
        vm.prank(user);
        vault.deposit(1 ether);

        vm.expectRevert(bytes("VAULT: amount is zero"));
        vm.prank(user);
        vault.withdraw(0);
    }

    function testWithdrawRevertsOnInsufficientCollateral() public {
        vm.prank(user);
        vault.deposit(1 ether);

        // Try to withdraw more than deposited (no debt, so _isSafe is not the blocker)
        vm.expectRevert(bytes("VAULT: insufficient collateral"));
        vm.prank(user);
        vault.withdraw(2 ether);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // mint zero-input guard (I-01)
    // ─────────────────────────────────────────────────────────────────────────

    function testMintRevertsOnZeroAmount() public {
        vm.prank(user);
        vault.deposit(1 ether);

        vm.expectRevert(bytes("VAULT: amount is zero"));
        vm.prank(user);
        vault.mint(0);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // burn input guards
    // ─────────────────────────────────────────────────────────────────────────

    function testBurnRevertsOnZeroAmount() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(user);
        vault.mint(1000e18);

        vm.expectRevert(bytes("VAULT: amount is zero"));
        vm.prank(user);
        vault.burn(0);
    }

    function testBurnRevertsWhenExceedingDebt() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(user);
        vault.mint(1000e18);

        vm.expectRevert(bytes("VAULT: burn exceeds debt"));
        vm.prank(user);
        vault.burn(1001e18);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Pause blocks withdraw and burn (whenNotPaused on all user ops)
    // ─────────────────────────────────────────────────────────────────────────

    function testPauseBlocksWithdraw() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(admin);
        vault.pause();

        vm.expectRevert();
        vm.prank(user);
        vault.withdraw(1 ether);
    }

    function testPauseBlocksBurn() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(user);
        vault.mint(1000e18);

        vm.prank(admin);
        vault.pause();

        vm.expectRevert();
        vm.prank(user);
        vault.burn(500e18);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CR boundary precision (I-01)
    // 2 ETH @ $2000 = $4000 value18.
    // max safe debt = floor(4000e18 * 10000 / 15000) = 2666e18
    //   2666e18 * 15000 = 39_990_000e18 <= 4000e18 * 10000 = 40_000_000e18  → pass
    //   2667e18 * 15000 = 40_005_000e18  > 40_000_000e18                    → revert
    // ─────────────────────────────────────────────────────────────────────────

    function testMintAtExactCRBoundarySucceeds() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(user);
        vault.mint(2666e18);

        assertEq(vault.debtOf(user), 2666e18);
    }

    function testMintOneUnitAboveCRBoundaryReverts() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.expectRevert(bytes("VAULT: unsafe mint"));
        vm.prank(user);
        vault.mint(2667e18);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Oracle staleness propagates through vault operations
    // Uses real OracleModule + vm.warp; error originates in OracleModule.
    // ─────────────────────────────────────────────────────────────────────────

    function testOracleStalenessBlocksMint() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.warp(block.timestamp + 2 hours);

        vm.expectRevert(bytes("ORACLE: stale"));
        vm.prank(user);
        vault.mint(1000e18);
    }

    function testOracleStalenessBlocksWithdrawWhenDebtExists() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(user);
        vault.mint(1000e18);

        vm.warp(block.timestamp + 2 hours);

        // withdraw calls _isSafe → _oracleSnapshot → oracle.getPrice() → ORACLE: stale
        vm.expectRevert(bytes("ORACLE: stale"));
        vm.prank(user);
        vault.withdraw(1 ether);
    }

    // Withdraw with no debt does NOT call oracle (d==0 → _isSafe returns true immediately)
    function testWithdrawWithNoDebtSucceedsAfterOracleGoesFresh() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.warp(block.timestamp + 2 hours);

        // No debt: _isSafe(user) returns true at d==0 branch, never touches oracle
        vm.prank(user);
        vault.withdraw(1 ether);

        assertEq(vault.collateralOf(user), 1 ether);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // VaultManager _oracleSnapshot vault-level guards
    // These require MockOracle that bypasses OracleModule's own identical checks.
    // ─────────────────────────────────────────────────────────────────────────

    function testVaultRevertsWhenOracleReturnsZeroUpdatedAt() public {
        MockOracle mockOracle = new MockOracle();
        mockOracle.setUpdatedAt(0);

        vm.prank(admin);
        vault.setOracle(address(mockOracle));

        vm.prank(user);
        vault.deposit(2 ether);

        vm.expectRevert(bytes("VAULT: oracle no update"));
        vm.prank(user);
        vault.mint(1000e18);
    }

    function testVaultRevertsWhenOracleReturnsFutureTimestamp() public {
        MockOracle mockOracle = new MockOracle();
        mockOracle.setUpdatedAt(block.timestamp + 100);

        vm.prank(admin);
        vault.setOracle(address(mockOracle));

        vm.prank(user);
        vault.deposit(2 ether);

        vm.expectRevert(bytes("VAULT: oracle time skew"));
        vm.prank(user);
        vault.mint(1000e18);
    }

    function testVaultRevertsWhenOracleReturnsStaleTimestamp() public {
        // MockOracle returns stale data that bypasses OracleModule's check
        // (updatedAt is in the past beyond vault's maxDelay=1hr, but valid: > 0 and <= now)
        // Warp ahead so block.timestamp is large enough to subtract 2 hours without underflow
        vm.warp(block.timestamp + 4 hours);

        MockOracle mockOracle = new MockOracle();
        mockOracle.setUpdatedAt(block.timestamp - 2 hours);

        vm.prank(admin);
        vault.setOracle(address(mockOracle));

        vm.prank(user);
        vault.deposit(2 ether);

        vm.expectRevert(bytes("VAULT: oracle stale"));
        vm.prank(user);
        vault.mint(1000e18);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // isLiquidatable edge cases
    // ─────────────────────────────────────────────────────────────────────────

    function testIsLiquidatableReturnsFalseForZeroDebt() public {
        vm.prank(user);
        vault.deposit(2 ether);
        // No debt minted
        assertFalse(vault.isLiquidatable(user));
    }

    function testIsLiquidatableReturnsFalseForHealthyVault() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(user);
        vault.mint(1000e18); // CR = 400% — healthy

        assertFalse(vault.isLiquidatable(user));
    }

    function testIsLiquidatableReturnsTrueForUndercollateralizedVault() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(user);
        vault.mint(2000e18); // CR = 200% at $2000

        // Drop to $1200: value = $2400, debt = $2000, CR = 120% < 130% liqCR
        feed.setRoundData(1200_00000000, block.timestamp);

        assertTrue(vault.isLiquidatable(user));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // liquidate() input validation — accessed directly with KEEPER_ROLE
    // ─────────────────────────────────────────────────────────────────────────

    function _grantKeeperToThis() internal {
        bytes32 keeperRole = vault.KEEPER_ROLE(); // read before prank to avoid consuming it
        vm.prank(admin);
        vault.grantRole(keeperRole, address(this));
    }

    function _openUnsafeVault() internal {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(user);
        vault.mint(2000e18);

        feed.setRoundData(1200_00000000, block.timestamp);
    }

    function testLiquidateRevertsOnAccountZero() public {
        _grantKeeperToThis();
        _openUnsafeVault();

        vm.expectRevert(bytes("VAULT: account is zero"));
        vault.liquidate(address(0), address(this), 100e18);
    }

    function testLiquidateRevertsOnLiquidatorZero() public {
        _grantKeeperToThis();
        _openUnsafeVault();

        vm.expectRevert(bytes("VAULT: liquidator is zero"));
        vault.liquidate(user, address(0), 100e18);
    }

    function testLiquidateRevertsOnRepayZero() public {
        _grantKeeperToThis();
        _openUnsafeVault();

        vm.expectRevert(bytes("VAULT: repay is zero"));
        vault.liquidate(user, address(this), 0);
    }

    function testLiquidateRevertsOnNoDebt() public {
        _grantKeeperToThis();

        vm.prank(user);
        vault.deposit(1 ether); // deposit but no mint

        vm.expectRevert(bytes("VAULT: no debt"));
        vault.liquidate(user, address(this), 100e18);
    }

    function testLiquidateRevertsWhenVaultIsHealthy() public {
        _grantKeeperToThis();

        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(user);
        vault.mint(1000e18); // CR = 400% at $2000 — well above 130% liqCR

        vm.expectRevert(bytes("VAULT: not liquidatable"));
        vault.liquidate(user, address(this), 500e18);
    }

    // repayAmount > debt: the if-branch caps repayAmount to d
    function testLiquidateCappsRepayAmountAtFullDebt() public {
        _grantKeeperToThis();
        _openUnsafeVault();

        // user has 2000e18 NXUSD from vault.mint call above
        uint256 debtBefore = vault.debtOf(user);
        assertEq(debtBefore, 2000e18);

        // repayAmount = 4000e18 (double debt) — should be capped to 2000e18
        // seize = 2000e18 * 10500/10000 * 1e8/1200e8 = 1.75e18 < 2e18 collateral: ok
        uint256 seize = vault.liquidate(user, address(this), debtBefore * 2);

        assertEq(vault.debtOf(user), 0, "debt should be fully cleared after cap");
        assertGt(seize, 0);
        assertEq(weth.balanceOf(address(this)), seize);
    }

    // Seize exceeds collateral: requires extreme price drop
    // Setup: user deposits 1 ETH, mints 600_000e18 via MockOracle at $1M/ETH,
    // then price crashes to $1/ETH → seize(600_000e18) = 630_000 ETH >> 1 ETH collateral
    function testLiquidateRevertsWhenSeizeExceedsCollateral() public {
        MockOracle mockOracle = new MockOracle();
        mockOracle.setUpdatedAt(block.timestamp);
        mockOracle.setPrice(1_000_000e8); // $1M per ETH

        vm.prank(admin);
        vault.setOracle(address(mockOracle));

        _grantKeeperToThis();

        address victim = address(0xDEAD);
        weth.mint(victim, 1 ether);
        vm.prank(victim);
        weth.approve(address(vault), type(uint256).max);

        vm.prank(victim);
        vault.deposit(1 ether);

        // 1 ETH @ $1M → value18 = 1e18 * 1_000_000e8/1e8 = 1_000_000e18
        // max safe at 150% CR: 1_000_000e18 * 10000 / 15000 = 666_666e18
        vm.prank(victim);
        vault.mint(600_000e18);

        // Crash price to $1 — CR = 1e18 / 600_000e18 ≈ 0.000167% → liquidatable
        mockOracle.setPrice(1e8);
        mockOracle.setUpdatedAt(block.timestamp);

        // seize = 600_000e18 * 10500/10000 * 1e8/1e8 = 630_000 ETH >> 1 ETH collateral
        vm.expectRevert(bytes("VAULT: seize exceeds collateral"));
        vault.liquidate(victim, address(this), 600_000e18);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // liquidationPreview() input validation
    // ─────────────────────────────────────────────────────────────────────────

    function testLiquidationPreviewRevertsOnZeroRepay() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(user);
        vault.mint(1000e18);

        vm.expectRevert(bytes("VAULT: repay is zero"));
        vault.liquidationPreview(user, 0);
    }

    function testLiquidationPreviewRevertsOnNoDebt() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.expectRevert(bytes("VAULT: no debt"));
        vault.liquidationPreview(user, 100e18);
    }

    // liquidationPreview seize > collateral (same extreme price crash setup)
    function testLiquidationPreviewRevertsWhenSeizeExceedsCollateral() public {
        MockOracle mockOracle = new MockOracle();
        mockOracle.setUpdatedAt(block.timestamp);
        mockOracle.setPrice(1_000_000e8);

        vm.prank(admin);
        vault.setOracle(address(mockOracle));

        vm.prank(user);
        vault.deposit(1 ether);

        vm.prank(user);
        vault.mint(600_000e18);

        mockOracle.setPrice(1e8);
        mockOracle.setUpdatedAt(block.timestamp);

        vm.expectRevert(bytes("VAULT: seize exceeds collateral"));
        vault.liquidationPreview(user, 600_000e18);
    }

    function testLiquidationPreviewHappyPath() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(user);
        vault.mint(1000e18);

        // 500e18 repay @ $2000: seize = 500e18 * 1.05 * 1e8/2000e8 = 0.2625 ETH
        uint256 seize = vault.liquidationPreview(user, 500e18);
        assertGt(seize, 0);
        assertLt(seize, 2 ether);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // I-07: State mutation ordering
    // State must be updated before external transfer calls.
    // ─────────────────────────────────────────────────────────────────────────

    // withdraw: collateralOf decremented, then _isSafe checked, then COLLATERAL.transfer
    function testWithdrawStateMutatedBeforeTransfer() public {
        vm.prank(user);
        vault.deposit(2 ether);

        uint256 balBefore = weth.balanceOf(user);

        vm.prank(user);
        vault.withdraw(1 ether);

        assertEq(vault.collateralOf(user), 1 ether, "collateral storage not decremented");
        assertEq(weth.balanceOf(user), balBefore + 1 ether, "transfer did not complete");
    }

    // mint: debtOf incremented, _isSafe checked, then NXUSD.mint — state before external
    function testMintStateMutatedBeforeMintCall() public {
        vm.prank(user);
        vault.deposit(2 ether);

        assertEq(vault.debtOf(user), 0);

        vm.prank(user);
        vault.mint(1000e18);

        assertEq(vault.debtOf(user), 1000e18, "debt storage not incremented");
        assertEq(nxusd.balanceOf(user), 1000e18, "nxusd not minted to user");
    }

    // burn: debtOf decremented before NXUSD.burn
    function testBurnStateMutatedBeforeBurnCall() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(user);
        vault.mint(1000e18);

        vm.prank(user);
        vault.burn(600e18);

        assertEq(vault.debtOf(user), 400e18, "debt storage not correctly decremented");
        assertEq(nxusd.balanceOf(user), 400e18, "nxusd balance not updated");
    }
}
