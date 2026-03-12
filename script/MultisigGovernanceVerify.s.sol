// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

interface IAccessControlMultiLike {
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface IMultiNXUSDLike is IAccessControlMultiLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function MINTER_ROLE() external view returns (bytes32);
    function BURNER_ROLE() external view returns (bytes32);
}

interface IMultiOracleLike is IAccessControlMultiLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

interface IMultiVaultLike is IAccessControlMultiLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function GUARDIAN_ROLE() external view returns (bytes32);
}

interface IMultiLiqLike is IAccessControlMultiLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function GUARDIAN_ROLE() external view returns (bytes32);
    function KEEPER_ROLE() external view returns (bytes32);
}

contract MultisigGovernanceVerifyScript is Script {
    error ZeroAddress(string label);
    error NotAContract(string label, address account);
    error VerificationFailed();

    struct Config {
        address nxusdToken;
        address oracleModule;
        address vaultManager;
        address liquidationEngine;
        address expectedSafeAdmin;
        address expectedOldAdmin;
        address expectedGuardian;
        address expectedKeeper;
        bool expectOldAdminPresent;
        bool expectSafeCode;
    }

    struct Findings {
        bool roleChecksOk;
        bool capabilityChecksOk;
        bool safeChecksOk;
    }

    function run() external view {
        Config memory cfg = _loadConfig();
        Findings memory f;
        f.roleChecksOk = true;
        f.capabilityChecksOk = true;
        f.safeChecksOk = true;

        _validateNonZero(cfg);

        console2.log("==================================================");
        console2.log("NEXUS CONTRACTS - MULTISIG GOVERNANCE VERIFY");
        console2.log("==================================================");
        console2.log("NXUSDToken          :", cfg.nxusdToken);
        console2.log("OracleModule        :", cfg.oracleModule);
        console2.log("VaultManager        :", cfg.vaultManager);
        console2.log("LiquidationEngine   :", cfg.liquidationEngine);
        console2.log("Expected Safe Admin :", cfg.expectedSafeAdmin);
        console2.log("Expected Old Admin  :", cfg.expectedOldAdmin);
        console2.log("Expected Guardian   :", cfg.expectedGuardian);
        console2.log("Expected Keeper     :", cfg.expectedKeeper);
        console2.log("Old Admin Expected? :", cfg.expectOldAdminPresent ? "YES" : "NO");
        console2.log("==================================================");

        IMultiNXUSDLike nxusd = IMultiNXUSDLike(cfg.nxusdToken);
        IMultiOracleLike oracle = IMultiOracleLike(cfg.oracleModule);
        IMultiVaultLike vault = IMultiVaultLike(cfg.vaultManager);
        IMultiLiqLike liq = IMultiLiqLike(cfg.liquidationEngine);

        if (cfg.expectSafeCode) {
            f.safeChecksOk = _checkContract("SAFE_ADMIN", cfg.expectedSafeAdmin) && f.safeChecksOk;
        }

        bool vaultHasGuardianGetter = _supportsSelector(cfg.vaultManager, IMultiVaultLike.GUARDIAN_ROLE.selector);
        bool vaultHasPausedGetter = _supportsSelector(cfg.vaultManager, bytes4(keccak256("paused()")));
        bool liqHasGuardianGetter = _supportsSelector(cfg.liquidationEngine, IMultiLiqLike.GUARDIAN_ROLE.selector);
        bool liqHasPausedGetter = _supportsSelector(cfg.liquidationEngine, bytes4(keccak256("paused()")));

        f.capabilityChecksOk =
            _checkCapability("VaultManager", "GUARDIAN_ROLE()", vaultHasGuardianGetter) && f.capabilityChecksOk;
        f.capabilityChecksOk =
            _checkCapability("VaultManager", "paused()", vaultHasPausedGetter) && f.capabilityChecksOk;
        f.capabilityChecksOk =
            _checkCapability("LiquidationEngine", "GUARDIAN_ROLE()", liqHasGuardianGetter) && f.capabilityChecksOk;
        f.capabilityChecksOk =
            _checkCapability("LiquidationEngine", "paused()", liqHasPausedGetter) && f.capabilityChecksOk;
        f.roleChecksOk = _checkRole(
            "NXUSDToken",
            "DEFAULT_ADMIN_ROLE(SAFE)",
            nxusd.hasRole(nxusd.DEFAULT_ADMIN_ROLE(), cfg.expectedSafeAdmin),
            cfg.expectedSafeAdmin
        ) && f.roleChecksOk;

        f.roleChecksOk = _checkRole(
            "OracleModule",
            "DEFAULT_ADMIN_ROLE(SAFE)",
            oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), cfg.expectedSafeAdmin),
            cfg.expectedSafeAdmin
        ) && f.roleChecksOk;

        f.roleChecksOk = _checkRole(
            "VaultManager",
            "DEFAULT_ADMIN_ROLE(SAFE)",
            vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), cfg.expectedSafeAdmin),
            cfg.expectedSafeAdmin
        ) && f.roleChecksOk;

        f.roleChecksOk = _checkRole(
            "LiquidationEngine",
            "DEFAULT_ADMIN_ROLE(SAFE)",
            liq.hasRole(liq.DEFAULT_ADMIN_ROLE(), cfg.expectedSafeAdmin),
            cfg.expectedSafeAdmin
        ) && f.roleChecksOk;

        f.roleChecksOk = _checkOldAdminRole(
            "NXUSDToken",
            nxusd.hasRole(nxusd.DEFAULT_ADMIN_ROLE(), cfg.expectedOldAdmin),
            cfg.expectedOldAdmin,
            cfg.expectOldAdminPresent
        ) && f.roleChecksOk;

        f.roleChecksOk = _checkOldAdminRole(
            "OracleModule",
            oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), cfg.expectedOldAdmin),
            cfg.expectedOldAdmin,
            cfg.expectOldAdminPresent
        ) && f.roleChecksOk;

        f.roleChecksOk = _checkOldAdminRole(
            "VaultManager",
            vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), cfg.expectedOldAdmin),
            cfg.expectedOldAdmin,
            cfg.expectOldAdminPresent
        ) && f.roleChecksOk;

        f.roleChecksOk = _checkOldAdminRole(
            "LiquidationEngine",
            liq.hasRole(liq.DEFAULT_ADMIN_ROLE(), cfg.expectedOldAdmin),
            cfg.expectedOldAdmin,
            cfg.expectOldAdminPresent
        ) && f.roleChecksOk;
        if (vaultHasGuardianGetter) {
            f.roleChecksOk = _checkRole(
                "VaultManager",
                "GUARDIAN_ROLE",
                vault.hasRole(vault.GUARDIAN_ROLE(), cfg.expectedGuardian),
                cfg.expectedGuardian
            ) && f.roleChecksOk;
        }

        if (liqHasGuardianGetter) {
            f.roleChecksOk = _checkRole(
                "LiquidationEngine",
                "GUARDIAN_ROLE",
                liq.hasRole(liq.GUARDIAN_ROLE(), cfg.expectedGuardian),
                cfg.expectedGuardian
            ) && f.roleChecksOk;
        }

        f.roleChecksOk = _checkRole(
            "LiquidationEngine", "KEEPER_ROLE", liq.hasRole(liq.KEEPER_ROLE(), cfg.expectedKeeper), cfg.expectedKeeper
        ) && f.roleChecksOk;

        f.roleChecksOk = _checkRole(
            "NXUSDToken", "MINTER_ROLE", nxusd.hasRole(nxusd.MINTER_ROLE(), cfg.vaultManager), cfg.vaultManager
        ) && f.roleChecksOk;

        f.roleChecksOk = _checkRole(
            "NXUSDToken", "BURNER_ROLE", nxusd.hasRole(nxusd.BURNER_ROLE(), cfg.vaultManager), cfg.vaultManager
        ) && f.roleChecksOk;

        console2.log("==================================================");
        console2.log("SAFE CODE CHECK        :", f.safeChecksOk ? "PASS" : "FAIL");
        console2.log("ROLE CHECK RESULT      :", f.roleChecksOk ? "PASS" : "FAIL");
        console2.log("CAPABILITY CHECK RESULT:", f.capabilityChecksOk ? "PASS" : "FAIL");

        if (!f.safeChecksOk || !f.roleChecksOk || !f.capabilityChecksOk) {
            console2.log("MULTISIG VERIFY RESULT : FAIL");
            revert VerificationFailed();
        }

        console2.log("MULTISIG VERIFY RESULT : PASS");
        console2.log("==================================================");
    }

    function _loadConfig() internal view returns (Config memory cfg) {
        cfg.nxusdToken = vm.envAddress("NXUSD_TOKEN");
        cfg.oracleModule = vm.envAddress("ORACLE_MODULE");
        cfg.vaultManager = vm.envAddress("VAULT_MANAGER");
        cfg.liquidationEngine = vm.envAddress("LIQUIDATION_ENGINE");
        cfg.expectedSafeAdmin = vm.envAddress("EXPECTED_SAFE_ADMIN");
        cfg.expectedOldAdmin = vm.envAddress("EXPECTED_OLD_ADMIN");
        cfg.expectedGuardian = vm.envAddress("EXPECTED_GUARDIAN");
        cfg.expectedKeeper = vm.envAddress("EXPECTED_KEEPER");
        cfg.expectOldAdminPresent = vm.envBool("EXPECT_OLD_ADMIN_PRESENT");
        cfg.expectSafeCode = vm.envBool("EXPECT_SAFE_CODE");
    }

    function _validateNonZero(Config memory cfg) internal view {
        if (cfg.nxusdToken == address(0)) revert ZeroAddress("NXUSD_TOKEN");
        if (cfg.oracleModule == address(0)) revert ZeroAddress("ORACLE_MODULE");
        if (cfg.vaultManager == address(0)) revert ZeroAddress("VAULT_MANAGER");
        if (cfg.liquidationEngine == address(0)) revert ZeroAddress("LIQUIDATION_ENGINE");
        if (cfg.expectedSafeAdmin == address(0)) revert ZeroAddress("EXPECTED_SAFE_ADMIN");
        if (cfg.expectedOldAdmin == address(0)) revert ZeroAddress("EXPECTED_OLD_ADMIN");
        if (cfg.expectedGuardian == address(0)) revert ZeroAddress("EXPECTED_GUARDIAN");
        if (cfg.expectedKeeper == address(0)) revert ZeroAddress("EXPECTED_KEEPER");

        _validateIsContract("NXUSD_TOKEN", cfg.nxusdToken);
        _validateIsContract("ORACLE_MODULE", cfg.oracleModule);
        _validateIsContract("VAULT_MANAGER", cfg.vaultManager);
        _validateIsContract("LIQUIDATION_ENGINE", cfg.liquidationEngine);
    }

    function _supportsSelector(address target, bytes4 selector) internal view returns (bool) {
        (bool ok,) = target.staticcall(abi.encodeWithSelector(selector));
        return ok;
    }

    function _validateIsContract(string memory label, address account) internal view {
        if (account.code.length == 0) revert NotAContract(label, account);
    }

    function _checkContract(string memory label, address account) internal view returns (bool) {
        if (account.code.length > 0) {
            console2.log("[PASS]", label, account);
            return true;
        }
        console2.log("[FAIL]", label, account);
        return false;
    }

    function _checkCapability(string memory contractLabel, string memory capabilityLabel, bool supported)
        internal
        pure
        returns (bool)
    {
        if (supported) {
            console2.log("[PASS]", contractLabel, capabilityLabel);
            return true;
        }
        console2.log("[MISSING_CAPABILITY]", contractLabel, capabilityLabel);
        return false;
    }

    function _checkRole(string memory contractLabel, string memory roleLabel, bool ok, address account)
        internal
        pure
        returns (bool)
    {
        if (ok) {
            console2.log("[PASS]", contractLabel, roleLabel, account);
            return true;
        }
        console2.log("[FAIL]", contractLabel, roleLabel, account);
        return false;
    }

    function _checkOldAdminRole(string memory contractLabel, bool hasRole, address account, bool expectedPresent)
        internal
        pure
        returns (bool)
    {
        if (expectedPresent && hasRole) {
            console2.log("[PASS]", contractLabel, "OLD_ADMIN_PRESENT", account);
            return true;
        }
        if (!expectedPresent && !hasRole) {
            console2.log("[PASS]", contractLabel, "OLD_ADMIN_REMOVED", account);
            return true;
        }
        console2.log("[FAIL]", contractLabel, expectedPresent ? "OLD_ADMIN_PRESENT" : "OLD_ADMIN_REMOVED", account);
        return false;
    }
}
