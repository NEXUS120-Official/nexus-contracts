// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// TimelockGovernance.t.sol
//
// Tests the NEXUS Finance governance properties that follow from the
// TimelockController configuration chosen in TIMELOCK_IMPLEMENTATION_PLAN.md.
//
// What is tested (not OZ logic -- the NEXUS configuration of it):
//   1. Open executor model: address(0) holds EXECUTOR_ROLE; any address can execute
//   2. Proposer gate: only Safe can schedule proposals
//   3. Canceller gate: only Safe can cancel proposals
//   4. Execution liveness: arbitrary address executes a ready proposal
//   5. Emergency control independence: pause() bypasses timelock (direct guardian call)
//   6. Unpause requires timelock path (DEFAULT_ADMIN_ROLE gated)
//   7. updateDelay requires timelock delay (cannot instant-reduce)
//   8. Proposal cancellation works within window
//
// These tests validate the security properties asserted in:
//   - TIMELOCK_IMPLEMENTATION_PLAN.md Sections 2.3, 8.5, and "Emergency Control Independence"
//   - MAINNET_GOVERNANCE_PACK.md Section 4.1 (Three-Authority Principle)

import {Test, console2} from "forge-std/Test.sol";
import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {NXUSDToken} from "../src/core/NXUSDToken.sol";
import {OracleModule} from "../src/oracle/OracleModule.sol";
import {VaultManager} from "../src/vault/VaultManager.sol";
import {LiquidationEngine} from "../src/vault/LiquidationEngine.sol";
import {MockAggregatorV3} from "./mocks/MockAggregatorV3.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract TimelockGovernanceTest is Test {
    // ---- Timelock config (mirrors DeployTimelockController.s.sol) --------
    uint256 constant MIN_DELAY = 48 * 3600; // 172800 seconds

    // ---- Actors -----------------------------------------------------------
    address safe = makeAddr("safe");
    address guardian = makeAddr("guardian");
    address keeper = makeAddr("keeper");
    address alice = makeAddr("alice"); // unprivileged third party
    address deployer = makeAddr("deployer");

    // ---- Contracts --------------------------------------------------------
    TimelockController timelock;
    NXUSDToken nxusd;
    OracleModule oracle;
    VaultManager vault;
    LiquidationEngine liq;
    MockAggregatorV3 feed;
    MockERC20 weth;

    // ---- Role constants ---------------------------------------------------
    bytes32 constant DEFAULT_ADMIN = bytes32(0);
    bytes32 constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    function setUp() public {
        // ---- Deploy TimelockController with NEXUS config ------------------
        address[] memory proposers = new address[](1);
        proposers[0] = safe;

        // Open execution: address(0) as executor
        address[] memory executors = new address[](1);
        executors[0] = address(0);

        timelock = new TimelockController(MIN_DELAY, proposers, executors, address(0));

        // ---- Deploy core contracts (deployer as initial admin) ------------
        feed = new MockAggregatorV3(8);
        feed.setRoundData(int256(2000e8), block.timestamp);
        weth = new MockERC20("Wrapped Ether", "WETH");

        vm.startPrank(deployer);

        nxusd = new NXUSDToken(deployer);
        oracle = new OracleModule(deployer, address(feed), 3600, address(0));
        vault = new VaultManager(deployer, address(weth), address(nxusd), address(oracle), 15000, 13000, 3600);
        liq = new LiquidationEngine(deployer, address(nxusd), address(vault), 5000);

        // Wire token roles
        nxusd.setMinter(address(vault), true);
        nxusd.setBurner(address(vault), true);

        // Wire KEEPER_ROLE: LiquidationEngine calls vault.liquidate()
        vault.grantRole(KEEPER_ROLE, address(liq));
        liq.grantRole(KEEPER_ROLE, keeper);

        // Wire GUARDIAN_ROLE: dedicated guardian
        vault.grantRole(GUARDIAN_ROLE, guardian);
        liq.grantRole(GUARDIAN_ROLE, guardian);

        // ---- Migrate DEFAULT_ADMIN_ROLE to TimelockController (Safe pattern)
        // Grant timelock admin on all four contracts
        nxusd.grantRole(DEFAULT_ADMIN, address(timelock));
        oracle.grantRole(DEFAULT_ADMIN, address(timelock));
        vault.grantRole(DEFAULT_ADMIN, address(timelock));
        liq.grantRole(DEFAULT_ADMIN, address(timelock));

        // Revoke GUARDIAN_ROLE from deployer (deployer got it via constructor)
        vault.revokeRole(GUARDIAN_ROLE, deployer);
        liq.revokeRole(GUARDIAN_ROLE, deployer);

        // Revoke DEFAULT_ADMIN_ROLE from deployer
        nxusd.revokeRole(DEFAULT_ADMIN, deployer);
        oracle.revokeRole(DEFAULT_ADMIN, deployer);
        vault.revokeRole(DEFAULT_ADMIN, deployer);
        liq.revokeRole(DEFAULT_ADMIN, deployer);

        vm.stopPrank();
    }

    // ======================================================================
    // Test 1 — Open executor model: address(0) holds EXECUTOR_ROLE
    // ======================================================================

    function testExecutorIsOpen() public view {
        assertTrue(timelock.hasRole(EXECUTOR_ROLE, address(0)), "address(0) must hold EXECUTOR_ROLE");
    }

    function testSafeDoesNotHoldExecutorRole() public view {
        assertFalse(timelock.hasRole(EXECUTOR_ROLE, safe), "Safe must NOT hold EXECUTOR_ROLE directly");
    }

    function testSafeHoldsProposerAndCanceller() public view {
        assertTrue(timelock.hasRole(PROPOSER_ROLE, safe), "Safe must hold PROPOSER_ROLE");
        assertTrue(timelock.hasRole(CANCELLER_ROLE, safe), "Safe must hold CANCELLER_ROLE");
    }

    function testTimelockIsSelfAdministered() public view {
        assertTrue(timelock.hasRole(DEFAULT_ADMIN, address(timelock)), "timelock must self-hold DEFAULT_ADMIN");
        assertFalse(timelock.hasRole(DEFAULT_ADMIN, safe), "Safe must NOT hold DEFAULT_ADMIN on timelock");
    }

    // ======================================================================
    // Test 2 — Proposer gate: only Safe can schedule
    // ======================================================================

    function testNonSafeCannotSchedule() public {
        bytes memory data = abi.encodeCall(NXUSDToken.setMaxSupply, (1_000_000e18));
        vm.prank(alice);
        vm.expectRevert();
        timelock.schedule(address(nxusd), 0, data, bytes32(0), bytes32(0), MIN_DELAY);
    }

    function testSafeCanSchedule() public {
        bytes memory data = abi.encodeCall(NXUSDToken.setMaxSupply, (1_000_000e18));
        vm.prank(safe);
        timelock.schedule(address(nxusd), 0, data, bytes32(0), bytes32(0), MIN_DELAY);
        // Operation is now in Waiting state
        bytes32 id = timelock.hashOperation(address(nxusd), 0, data, bytes32(0), bytes32(0));
        assertTrue(timelock.isOperationPending(id), "operation must be pending after schedule");
    }

    // ======================================================================
    // Test 3 — Execution liveness: arbitrary address can execute after delay
    // ======================================================================

    function testArbitraryAddressCanExecuteAfterDelay() public {
        bytes memory data = abi.encodeCall(NXUSDToken.setMaxSupply, (1_000_000e18));
        bytes32 salt = bytes32(uint256(1));

        // Safe schedules
        vm.prank(safe);
        timelock.schedule(address(nxusd), 0, data, bytes32(0), salt, MIN_DELAY);

        // Advance past delay
        vm.warp(block.timestamp + MIN_DELAY + 1);

        // Alice (no roles whatsoever) executes
        vm.prank(alice);
        timelock.execute(address(nxusd), 0, data, bytes32(0), salt);

        // Verify the operation applied
        assertEq(nxusd.maxSupply(), 1_000_000e18, "setMaxSupply must have applied");
    }

    function testArbitraryAddressCannotExecuteBeforeDelay() public {
        bytes memory data = abi.encodeCall(NXUSDToken.setMaxSupply, (2_000_000e18));
        bytes32 salt = bytes32(uint256(2));

        vm.prank(safe);
        timelock.schedule(address(nxusd), 0, data, bytes32(0), salt, MIN_DELAY);

        // Do NOT advance time -- still in Waiting state
        vm.prank(alice);
        vm.expectRevert(); // TimelockUnexpectedOperationState
        timelock.execute(address(nxusd), 0, data, bytes32(0), salt);
    }

    // ======================================================================
    // Test 4 — Emergency control independence: pause() bypasses timelock
    //
    // This is the CRITICAL property from Section "Emergency Control Independence"
    // in TIMELOCK_IMPLEMENTATION_PLAN.md.
    // Guardian calls pause() directly on contracts. The timelock is NOT involved.
    // pause() requires GUARDIAN_ROLE, which is held directly on the contracts --
    // NOT by the TimelockController.
    // ======================================================================

    function testGuardianCanPauseVaultDirectlyNoTimelock() public {
        assertFalse(vault.paused(), "vault must start unpaused");

        // Guardian calls pause() directly -- no timelock, no delay
        vm.prank(guardian);
        vault.pause();

        assertTrue(vault.paused(), "vault must be paused after guardian.pause()");
    }

    function testGuardianCanPauseLiqEngineDirectlyNoTimelock() public {
        assertFalse(liq.paused(), "liq engine must start unpaused");

        vm.prank(guardian);
        liq.pause();

        assertTrue(liq.paused(), "liq engine must be paused after guardian.pause()");
    }

    function testArbitraryAddressCannotPause() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.pause();
    }

    function testTimelockDoesNotHoldGuardianRole() public view {
        // The TimelockController holds DEFAULT_ADMIN_ROLE, not GUARDIAN_ROLE.
        // This separation is what makes pause() independent of the governance delay.
        assertFalse(vault.hasRole(GUARDIAN_ROLE, address(timelock)));
        assertFalse(liq.hasRole(GUARDIAN_ROLE, address(timelock)));
    }

    // ======================================================================
    // Test 5 — Unpause requires timelock (DEFAULT_ADMIN_ROLE gated)
    // ======================================================================

    function testGuardianCannotUnpause() public {
        vm.prank(guardian);
        vault.pause();

        // Guardian cannot unpause -- only DEFAULT_ADMIN_ROLE can
        vm.prank(guardian);
        vm.expectRevert();
        vault.unpause();
    }

    function testTimelockCanUnpauseAfterDelay() public {
        // Pause first
        vm.prank(guardian);
        vault.pause();
        assertTrue(vault.paused());

        // Queue unpause through timelock
        bytes memory data = abi.encodeWithSignature("unpause()");
        bytes32 salt = bytes32(uint256(99));

        vm.prank(safe);
        timelock.schedule(address(vault), 0, data, bytes32(0), salt, MIN_DELAY);

        vm.warp(block.timestamp + MIN_DELAY + 1);

        // Anyone can execute (open execution)
        timelock.execute(address(vault), 0, data, bytes32(0), salt);

        assertFalse(vault.paused(), "vault must be unpaused after timelock execution");
    }

    // ======================================================================
    // Test 6 — updateDelay requires timelock delay (cannot instant-reduce)
    // This validates the protection against the minDelay reduction attack
    // documented in TIMELOCK_IMPLEMENTATION_PLAN.md Section 8.5.
    // ======================================================================

    function testUpdateDelayRequiresTimelockDelay() public {
        uint256 currentDelay = timelock.getMinDelay();
        assertEq(currentDelay, MIN_DELAY);

        // Attempting to call updateDelay directly -- only timelock can call itself
        vm.prank(safe);
        vm.expectRevert();
        timelock.updateDelay(0);
    }

    function testUpdateDelayViaTimelockEnforcesDelay() public {
        // To reduce minDelay, must go through the timelock itself (48h wait)
        bytes memory data = abi.encodeWithSignature("updateDelay(uint256)", uint256(24 * 3600));
        bytes32 salt = bytes32(uint256(42));

        // Schedule -- only at the CURRENT delay, not the proposed new delay
        vm.prank(safe);
        timelock.schedule(address(timelock), 0, data, bytes32(0), salt, MIN_DELAY);

        // Cannot execute before current delay elapses
        vm.warp(block.timestamp + 24 * 3600); // only 24h -- less than current 48h
        vm.expectRevert();
        timelock.execute(address(timelock), 0, data, bytes32(0), salt);

        // After full current delay, execution succeeds
        vm.warp(block.timestamp + 24 * 3600 + 1); // total 48h+
        timelock.execute(address(timelock), 0, data, bytes32(0), salt);

        assertEq(timelock.getMinDelay(), 24 * 3600, "minDelay must be updated to 24h");
    }

    // ======================================================================
    // Test 7 — Cancellation works within delay window
    // ======================================================================

    function testSafeCanCancelPendingProposal() public {
        bytes memory data = abi.encodeCall(NXUSDToken.setMaxSupply, (5_000_000e18));
        bytes32 salt = bytes32(uint256(7));

        vm.prank(safe);
        timelock.schedule(address(nxusd), 0, data, bytes32(0), salt, MIN_DELAY);

        bytes32 id = timelock.hashOperation(address(nxusd), 0, data, bytes32(0), salt);
        assertTrue(timelock.isOperationPending(id));

        // Cancel before delay elapses
        vm.prank(safe);
        timelock.cancel(id);

        assertFalse(timelock.isOperation(id), "operation must be gone after cancel");
    }

    function testNonCancellerCannotCancel() public {
        bytes memory data = abi.encodeCall(NXUSDToken.setMaxSupply, (5_000_000e18));
        bytes32 salt = bytes32(uint256(8));

        vm.prank(safe);
        timelock.schedule(address(nxusd), 0, data, bytes32(0), salt, MIN_DELAY);

        bytes32 id = timelock.hashOperation(address(nxusd), 0, data, bytes32(0), salt);

        vm.prank(alice); // not a canceller
        vm.expectRevert();
        timelock.cancel(id);
    }

    // ======================================================================
    // Test 8 -- Role topology post-migration
    // ======================================================================

    function testTimelockHoldsAdminOnAllContracts() public view {
        assertTrue(nxusd.hasRole(DEFAULT_ADMIN, address(timelock)));
        assertTrue(oracle.hasRole(DEFAULT_ADMIN, address(timelock)));
        assertTrue(vault.hasRole(DEFAULT_ADMIN, address(timelock)));
        assertTrue(liq.hasRole(DEFAULT_ADMIN, address(timelock)));
    }

    function testDeployerHoldsNoRoles() public view {
        assertFalse(nxusd.hasRole(DEFAULT_ADMIN, deployer));
        assertFalse(oracle.hasRole(DEFAULT_ADMIN, deployer));
        assertFalse(vault.hasRole(DEFAULT_ADMIN, deployer));
        assertFalse(liq.hasRole(DEFAULT_ADMIN, deployer));
        assertFalse(vault.hasRole(GUARDIAN_ROLE, deployer));
        assertFalse(liq.hasRole(GUARDIAN_ROLE, deployer));
    }

    function testGuardianHoldsGuardianRoleOnProtocol() public view {
        assertTrue(vault.hasRole(GUARDIAN_ROLE, guardian));
        assertTrue(liq.hasRole(GUARDIAN_ROLE, guardian));
    }
}
