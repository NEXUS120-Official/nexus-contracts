// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// NEXUS Finance -- TimelockController Deploy Script (v1.1 -- Hardened)
//
// Purpose:
//   Deploy the OZ v5.6.0 TimelockController that will hold DEFAULT_ADMIN_ROLE
//   on all four NEXUS core contracts (NXUSDToken, OracleModule, VaultManager,
//   LiquidationEngine). The deployer EOA does not receive any role on the
//   timelock or on any core contract.
//
// Executor model -- OPEN EXECUTION:
//   executors = [address(0)]
//   Meaning: ANY address may call execute() on a proposal that has already
//   waited >= minDelay. This does NOT weaken the security model because:
//     - Only the Safe (PROPOSER_ROLE) can schedule proposals.
//     - The proposal content is locked at schedule time (cannot be modified).
//     - An executor cannot change WHAT executes -- only WHEN it executes.
//     - Open execution ensures execution liveness: if the Safe is temporarily
//       unavailable at execution time, any address (keeper bot, protocol team,
//       community member) can call execute() after the delay elapses.
//     - Without open execution, a single Safe unavailability event blocks
//       all governance actions indefinitely.
//   Residual risk: none beyond liveness improvement.
//
// Required env vars:
//   PRIVATE_KEY       -- deployer EOA private key (needs ETH for gas only)
//   SAFE_MAINNET      -- mainnet Safe 4-of-7 address (proposer + canceller only)
//
// What this script does:
//   1. Deploys TimelockController with minDelay = 48 hours
//   2. Wires Safe as PROPOSER_ROLE + CANCELLER_ROLE (not EXECUTOR_ROLE)
//   3. Wires address(0) as EXECUTOR_ROLE (open execution)
//   4. Sets admin = address(0) -- timelock is self-administered
//   5. Asserts post-deploy role topology
//   6. Logs the timelock address for runbook recording
//
// What this script does NOT do:
//   - Does not migrate DEFAULT_ADMIN_ROLE from Safe to Timelock on core contracts.
//   - Does not revoke any roles from the Safe.
//   Migration is a separate Safe MultiSend batch (see TIMELOCK_IMPLEMENTATION_PLAN.md).
//
// Run (dry-run -- ALWAYS run this first):
//   forge script script/DeployTimelockController.s.sol \
//     --rpc-url $ARBITRUM_ONE_RPC_URL --fork-block-number <N> --dry-run -vvv
//
//   Confirm output: "POST-DEPLOY ASSERT : PASS", no reverts, gas < 2M.
//
// Run (live):
//   forge script script/DeployTimelockController.s.sol \
//     --rpc-url $ARBITRUM_ONE_RPC_URL --broadcast --verify -vvv

import {Script, console2} from "forge-std/Script.sol";
import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";

contract DeployTimelockControllerScript is Script {
    /// @notice Global minimum delay for all governance operations: 48 hours.
    ///         Covers the highest-risk function class (oracle change, minter grant,
    ///         vault replacement). 24h-class functions (setRatios, setMaxDelay,
    ///         setMaxSupply) inherit the same delay -- extra conservatism accepted.
    ///         Per-function delays require a custom TimelockController (post-audit scope).
    uint256 public constant MIN_DELAY = 48 * 3600; // 172800 seconds

    function run() external {
        address safe = vm.envAddress("SAFE_MAINNET");
        uint256 deployerPk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPk);

        require(safe != address(0), "DEPLOY: SAFE_MAINNET is zero");
        require(deployer != address(0), "DEPLOY: deployer is zero");
        require(safe != deployer, "DEPLOY: safe == deployer - misconfiguration");

        console2.log("=== NEXUS TIMELOCK PRE-DEPLOY ===");
        console2.log("Deployer EOA          :", deployer);
        console2.log("Safe (proposer)       :", safe);
        console2.log("Executor model        : OPEN (address(0))");
        console2.log("minDelay (seconds)    :", MIN_DELAY);
        console2.log("minDelay (hours)      :", MIN_DELAY / 3600);

        // Safe is sole PROPOSER (and auto-granted CANCELLER by OZ v5 constructor).
        // Safe does NOT hold EXECUTOR_ROLE.
        address[] memory proposers = new address[](1);
        proposers[0] = safe;

        // address(0) in executors = open execution.
        // Any address can call execute() on a Ready proposal.
        address[] memory executors = new address[](1);
        executors[0] = address(0);

        // admin = address(0): self-administered only. No external party holds
        // DEFAULT_ADMIN_ROLE on the TimelockController itself. Changing minDelay
        // or adding proposers/executors requires a 48h proposal through the timelock.
        address admin = address(0);

        vm.startBroadcast(deployerPk);
        TimelockController timelock = new TimelockController(MIN_DELAY, proposers, executors, admin);
        vm.stopBroadcast();

        // ---- Post-deploy assertions ------------------------------------------
        bytes32 PROPOSER_ROLE = timelock.PROPOSER_ROLE();
        bytes32 EXECUTOR_ROLE = timelock.EXECUTOR_ROLE();
        bytes32 CANCELLER_ROLE = timelock.CANCELLER_ROLE();
        bytes32 adminRole = bytes32(0); // DEFAULT_ADMIN_ROLE

        // Safe: PROPOSER + CANCELLER only (not EXECUTOR)
        require(timelock.hasRole(PROPOSER_ROLE, safe), "ASSERT: Safe missing PROPOSER_ROLE");
        require(!timelock.hasRole(EXECUTOR_ROLE, safe), "ASSERT: Safe has EXECUTOR_ROLE -- unexpected");
        require(timelock.hasRole(CANCELLER_ROLE, safe), "ASSERT: Safe missing CANCELLER_ROLE");

        // Open execution: address(0) holds EXECUTOR_ROLE
        require(timelock.hasRole(EXECUTOR_ROLE, address(0)), "ASSERT: address(0) missing EXECUTOR_ROLE");

        // Self-administered: timelock holds its own DEFAULT_ADMIN_ROLE; no external admin
        require(timelock.hasRole(adminRole, address(timelock)), "ASSERT: timelock not self-holding DEFAULT_ADMIN_ROLE");
        require(!timelock.hasRole(adminRole, safe), "ASSERT: Safe has DEFAULT_ADMIN_ROLE on timelock");
        require(!timelock.hasRole(adminRole, deployer), "ASSERT: deployer has DEFAULT_ADMIN_ROLE on timelock");

        // Deployer must NOT have any operational role
        require(!timelock.hasRole(PROPOSER_ROLE, deployer), "ASSERT: deployer has PROPOSER_ROLE");
        require(!timelock.hasRole(EXECUTOR_ROLE, deployer), "ASSERT: deployer has EXECUTOR_ROLE");

        // Delay is correct
        require(timelock.getMinDelay() == MIN_DELAY, "ASSERT: wrong minDelay");

        // ---- Output --------------------------------------------------------
        console2.log("=== NEXUS TIMELOCK DEPLOYED ===");
        console2.log("TimelockController    :", address(timelock));
        console2.log("Safe (proposer)       :", safe);
        console2.log("minDelay (seconds)    :", timelock.getMinDelay());
        console2.log("minDelay (hours)      :", timelock.getMinDelay() / 3600);
        console2.log("Safe PROPOSER         :", timelock.hasRole(PROPOSER_ROLE, safe));
        console2.log("Safe EXECUTOR         :", timelock.hasRole(EXECUTOR_ROLE, safe));
        console2.log("Safe CANCELLER        :", timelock.hasRole(CANCELLER_ROLE, safe));
        console2.log("Open EXECUTOR (0x0)   :", timelock.hasRole(EXECUTOR_ROLE, address(0)));
        console2.log("Self ADMIN            :", timelock.hasRole(adminRole, address(timelock)));
        console2.log("Safe ADMIN            :", timelock.hasRole(adminRole, safe));
        console2.log("Deployer ADMIN        :", timelock.hasRole(adminRole, deployer));
        console2.log("POST-DEPLOY ASSERT    :", "PASS");
        console2.log("");
        console2.log("NEXT: record address in MAINNET_DEPLOY_RUNBOOK.md");
        console2.log("NEXT: simulate Phase B migration batch on Tenderly fork");
        console2.log("NEXT: execute Safe migration batch (12 ops)");
        console2.log("NEXT: run TimelockMigrationVerify.s.sol to confirm");
    }
}
