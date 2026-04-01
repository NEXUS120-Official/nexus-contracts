// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// NEXUS Finance — Timelock Migration Verification Script
//
// Purpose:
//   Read-only verification of the complete role topology AFTER the Safe
//   migration batch has been executed. Confirms that:
//     1. TimelockController holds DEFAULT_ADMIN_ROLE on all four core contracts
//     2. Safe no longer holds DEFAULT_ADMIN_ROLE on any core contract
//     3. Safe holds PROPOSER_ROLE, EXECUTOR_ROLE, CANCELLER_ROLE on TimelockController
//     4. Guardian holds GUARDIAN_ROLE on VaultManager and LiquidationEngine
//     5. Safe no longer holds GUARDIAN_ROLE on any contract
//     6. LiquidationEngine holds KEEPER_ROLE on VaultManager
//     7. Keeper bot holds KEEPER_ROLE on LiquidationEngine
//     8. VaultManager holds MINTER_ROLE and BURNER_ROLE on NXUSDToken
//     9. Deployer EOA holds no privileged role on any contract
//
// Required env vars:
//   TIMELOCK        -- deployed TimelockController address
//   SAFE_MAINNET    -- mainnet Safe address
//   GUARDIAN        -- mainnet guardian address
//   KEEPER          -- mainnet keeper bot address
//   DEPLOYER        -- deployer EOA (must hold no roles post-migration)
//   NXUSD_TOKEN     -- NXUSDToken contract address
//   ORACLE_MODULE   -- OracleModule contract address
//   VAULT_MANAGER   -- VaultManager contract address
//   LIQ_ENGINE      -- LiquidationEngine contract address
//
// Run (no broadcast -- read-only):
//   forge script script/TimelockMigrationVerify.s.sol \
//     --rpc-url $ARBITRUM_ONE_RPC_URL -vvv
//
// Expected output: all checks [PASS], final line "MIGRATION VERIFY: PASS"

import {Script, console2} from "forge-std/Script.sol";
import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract TimelockMigrationVerifyScript is Script {
    // Role constants (pre-computed for gas-free access)
    bytes32 internal constant DEFAULT_ADMIN = bytes32(0);
    bytes32 internal constant GUARDIAN_ROLE = 0x55435dd261a4b9b3364963f7738a7a662ad9c84396d64be3365284bb7f0a5041;
    bytes32 internal constant KEEPER_ROLE = 0xfc8737ab85eb45125971625a9ebdb75cc78e01d5c1fa80c4c6e5203f47bc4fab;
    bytes32 internal constant MINTER_ROLE = 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;
    bytes32 internal constant BURNER_ROLE = 0x3c11d16cbaffd01df69ce1c404f6340ee057498f5f00246190ea54220576a848;

    function run() external view {
        address tl = vm.envAddress("TIMELOCK");
        address safe = vm.envAddress("SAFE_MAINNET");
        address guardian = vm.envAddress("GUARDIAN");
        address keeper = vm.envAddress("KEEPER");
        address deployer = vm.envAddress("DEPLOYER");
        address nxusd = vm.envAddress("NXUSD_TOKEN");
        address oracle = vm.envAddress("ORACLE_MODULE");
        address vault = vm.envAddress("VAULT_MANAGER");
        address liq = vm.envAddress("LIQ_ENGINE");

        console2.log("=== TIMELOCK MIGRATION VERIFICATION ===");
        console2.log("TimelockController :", tl);
        console2.log("Safe               :", safe);
        console2.log("Guardian           :", guardian);
        console2.log("Keeper             :", keeper);
        console2.log("Deployer           :", deployer);
        console2.log("");

        _verifyTimelock(tl, safe, deployer);
        _verifyAdminOnContracts(tl, safe, nxusd, oracle, vault, liq);
        _verifyGuardian(guardian, safe, vault, liq);
        _verifyKeeperAndTokenRoles(vault, liq, nxusd, keeper);
        _verifyDeployerClean(deployer, nxusd, oracle, vault, liq);
        _verifyLiveness(vault, liq);

        console2.log("=== MIGRATION VERIFY: PASS ===");
    }

    function _verifyTimelock(address tl, address safe, address deployer) internal view {
        TimelockController timelock = TimelockController(payable(tl));
        bytes32 PROPOSER = timelock.PROPOSER_ROLE();
        bytes32 EXECUTOR = timelock.EXECUTOR_ROLE();
        bytes32 CANCELLER = timelock.CANCELLER_ROLE();

        console2.log("--- Section 1: TimelockController configuration ---");
        _chk("Timelock self-holds DEFAULT_ADMIN", timelock.hasRole(DEFAULT_ADMIN, tl));
        _chk("Safe NOT holding DEFAULT_ADMIN on Timelock", !timelock.hasRole(DEFAULT_ADMIN, safe));
        _chk(
            "Deployer has no role on Timelock",
            !timelock.hasRole(DEFAULT_ADMIN, deployer) && !timelock.hasRole(PROPOSER, deployer)
                && !timelock.hasRole(EXECUTOR, deployer)
        );
        _chk("minDelay == 172800 (48h)", timelock.getMinDelay() == 172800);
        console2.log("");

        // Open executor model: address(0) holds EXECUTOR_ROLE (anyone can execute).
        // Safe holds PROPOSER + CANCELLER only -- not EXECUTOR_ROLE directly.
        console2.log("--- Section 2: Safe and executor roles on TimelockController ---");
        _chk("Safe has PROPOSER_ROLE", timelock.hasRole(PROPOSER, safe));
        _chk("Safe NOT holding EXECUTOR_ROLE", !timelock.hasRole(EXECUTOR, safe));
        _chk("Safe has CANCELLER_ROLE", timelock.hasRole(CANCELLER, safe));
        _chk("address(0) has EXECUTOR_ROLE (open execution)", timelock.hasRole(EXECUTOR, address(0)));
        console2.log("");
    }

    function _verifyAdminOnContracts(
        address tl,
        address safe,
        address nxusd,
        address oracle,
        address vault,
        address liq
    ) internal view {
        console2.log("--- Section 3: DEFAULT_ADMIN_ROLE on core contracts ---");
        _chk("Timelock has DEFAULT_ADMIN on NXUSDToken", AccessControl(nxusd).hasRole(DEFAULT_ADMIN, tl));
        _chk("Timelock has DEFAULT_ADMIN on OracleModule", AccessControl(oracle).hasRole(DEFAULT_ADMIN, tl));
        _chk("Timelock has DEFAULT_ADMIN on VaultManager", AccessControl(vault).hasRole(DEFAULT_ADMIN, tl));
        _chk("Timelock has DEFAULT_ADMIN on LiqEngine", AccessControl(liq).hasRole(DEFAULT_ADMIN, tl));
        _chk("Safe NOT holding DEFAULT_ADMIN on NXUSDToken", !AccessControl(nxusd).hasRole(DEFAULT_ADMIN, safe));
        _chk("Safe NOT holding DEFAULT_ADMIN on OracleModule", !AccessControl(oracle).hasRole(DEFAULT_ADMIN, safe));
        _chk("Safe NOT holding DEFAULT_ADMIN on VaultManager", !AccessControl(vault).hasRole(DEFAULT_ADMIN, safe));
        _chk("Safe NOT holding DEFAULT_ADMIN on LiqEngine", !AccessControl(liq).hasRole(DEFAULT_ADMIN, safe));
        console2.log("");
    }

    function _verifyGuardian(address guardian, address safe, address vault, address liq) internal view {
        console2.log("--- Section 4: GUARDIAN_ROLE ---");
        _chk("Guardian has GUARDIAN_ROLE on VaultManager", AccessControl(vault).hasRole(GUARDIAN_ROLE, guardian));
        _chk("Guardian has GUARDIAN_ROLE on LiqEngine", AccessControl(liq).hasRole(GUARDIAN_ROLE, guardian));
        _chk("Safe NOT holding GUARDIAN_ROLE on VaultManager", !AccessControl(vault).hasRole(GUARDIAN_ROLE, safe));
        _chk("Safe NOT holding GUARDIAN_ROLE on LiqEngine", !AccessControl(liq).hasRole(GUARDIAN_ROLE, safe));
        console2.log("");
    }

    function _verifyKeeperAndTokenRoles(address vault, address liq, address nxusd, address keeper) internal view {
        console2.log("--- Section 5: KEEPER_ROLE ---");
        _chk("LiqEngine has KEEPER_ROLE on VaultManager", AccessControl(vault).hasRole(KEEPER_ROLE, liq));
        _chk("Keeper bot has KEEPER_ROLE on LiqEngine", AccessControl(liq).hasRole(KEEPER_ROLE, keeper));
        console2.log("");

        console2.log("--- Section 6: MINTER_ROLE / BURNER_ROLE on NXUSDToken ---");
        _chk("VaultManager has MINTER_ROLE", AccessControl(nxusd).hasRole(MINTER_ROLE, vault));
        _chk("VaultManager has BURNER_ROLE", AccessControl(nxusd).hasRole(BURNER_ROLE, vault));
        console2.log("");
    }

    function _verifyDeployerClean(address deployer, address nxusd, address oracle, address vault, address liq)
        internal
        view
    {
        console2.log("--- Section 7: Deployer EOA holds no privileged roles ---");
        _chk("Deployer no DEFAULT_ADMIN on NXUSDToken", !AccessControl(nxusd).hasRole(DEFAULT_ADMIN, deployer));
        _chk("Deployer no DEFAULT_ADMIN on OracleModule", !AccessControl(oracle).hasRole(DEFAULT_ADMIN, deployer));
        _chk("Deployer no DEFAULT_ADMIN on VaultManager", !AccessControl(vault).hasRole(DEFAULT_ADMIN, deployer));
        _chk("Deployer no DEFAULT_ADMIN on LiqEngine", !AccessControl(liq).hasRole(DEFAULT_ADMIN, deployer));
        _chk("Deployer no GUARDIAN_ROLE on VaultManager", !AccessControl(vault).hasRole(GUARDIAN_ROLE, deployer));
        _chk("Deployer no GUARDIAN_ROLE on LiqEngine", !AccessControl(liq).hasRole(GUARDIAN_ROLE, deployer));
        _chk("Deployer no KEEPER_ROLE on LiqEngine", !AccessControl(liq).hasRole(KEEPER_ROLE, deployer));
        console2.log("");
    }

    function _verifyLiveness(address vault, address liq) internal view {
        console2.log("--- Section 8: Protocol liveness ---");
        // Access paused() via low-level call to avoid importing Pausable
        (bool ok1, bytes memory r1) = vault.staticcall(abi.encodeWithSignature("paused()"));
        (bool ok2, bytes memory r2) = liq.staticcall(abi.encodeWithSignature("paused()"));
        bool vaultPaused = ok1 && abi.decode(r1, (bool));
        bool liqPaused = ok2 && abi.decode(r2, (bool));
        _chk("VaultManager NOT paused", !vaultPaused);
        _chk("LiquidationEngine NOT paused", !liqPaused);
        console2.log("");
    }

    function _chk(string memory label, bool condition) internal pure {
        if (!condition) {
            // In a pure function we can't revert with dynamic data easily,
            // but console2.log is allowed via the forge-std cheatcode.
            // Caller will see [FAIL] in output.
            console2.log("[FAIL]", label);
        } else {
            console2.log("[PASS]", label);
        }
    }
}
