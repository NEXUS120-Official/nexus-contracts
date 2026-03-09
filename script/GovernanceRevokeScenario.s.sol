// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IAccessControlRevokeScenarioLike {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function revokeRole(bytes32 role, address account) external;
}

interface IRevokeNXUSDLike is IAccessControlRevokeScenarioLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

interface IRevokeOracleLike is IAccessControlRevokeScenarioLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

interface IRevokeVaultLike is IAccessControlRevokeScenarioLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function GUARDIAN_ROLE() external view returns (bytes32);
}

interface IRevokeLiqLike is IAccessControlRevokeScenarioLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function GUARDIAN_ROLE() external view returns (bytes32);
    function KEEPER_ROLE() external view returns (bytes32);
}

contract GovernanceRevokeScenarioScript is Script {
    error ZeroAddress(string label);
    error NotAContract(string label, address account);
    error ScenarioVerificationFailed(string phase, string item);

    struct Config {
        address nxusdToken;
        address oracleModule;
        address vaultManager;
        address liquidationEngine;
        address oldAdmin;
        address newAdmin;
        address newGuardian;
        address newKeeper;
    }

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        Config memory cfg = _loadConfig();
        _validateConfig(cfg);

        IRevokeNXUSDLike nxusd = IRevokeNXUSDLike(cfg.nxusdToken);
        IRevokeOracleLike oracle = IRevokeOracleLike(cfg.oracleModule);
        IRevokeVaultLike vault = IRevokeVaultLike(cfg.vaultManager);
        IRevokeLiqLike liq = IRevokeLiqLike(cfg.liquidationEngine);

        console2.log("==================================================");
        console2.log("NEXUS CONTRACTS - GOVERNANCE REVOKE SCENARIO");
        console2.log("==================================================");
        console2.log("Old Admin         :", cfg.oldAdmin);
        console2.log("New Admin         :", cfg.newAdmin);
        console2.log("New Guardian      :", cfg.newGuardian);
        console2.log("New Keeper        :", cfg.newKeeper);
        console2.log("==================================================");
        _requireHasRole(
            vault.hasRole(vault.GUARDIAN_ROLE(), cfg.newGuardian), "PRECHECK", "new guardian on VaultManager"
        );
        _requireHasRole(
            liq.hasRole(liq.GUARDIAN_ROLE(), cfg.newGuardian), "PRECHECK", "new guardian on LiquidationEngine"
        );
        _requireHasRole(liq.hasRole(liq.KEEPER_ROLE(), cfg.newKeeper), "PRECHECK", "new keeper on LiquidationEngine");
        _requireHasRole(nxusd.hasRole(nxusd.DEFAULT_ADMIN_ROLE(), cfg.newAdmin), "PRECHECK", "new admin on NXUSDToken");
        _requireHasRole(
            oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), cfg.newAdmin), "PRECHECK", "new admin on OracleModule"
        );
        _requireHasRole(
            vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), cfg.newAdmin), "PRECHECK", "new admin on VaultManager"
        );
        _requireHasRole(
            liq.hasRole(liq.DEFAULT_ADMIN_ROLE(), cfg.newAdmin), "PRECHECK", "new admin on LiquidationEngine"
        );

        vm.startBroadcast(pk);
        vault.revokeRole(vault.GUARDIAN_ROLE(), cfg.oldAdmin);
        liq.revokeRole(liq.GUARDIAN_ROLE(), cfg.oldAdmin);

        vm.stopBroadcast();

        _requireLacksRole(
            vault.hasRole(vault.GUARDIAN_ROLE(), cfg.oldAdmin),
            "PHASE_A_GUARDIAN_REVOKE",
            "legacy guardian removed from VaultManager"
        );
        _requireLacksRole(
            liq.hasRole(liq.GUARDIAN_ROLE(), cfg.oldAdmin),
            "PHASE_A_GUARDIAN_REVOKE",
            "legacy guardian removed from LiquidationEngine"
        );

        console2.log("PHASE_A_GUARDIAN_REVOKE : PASS");
        vm.startBroadcast(pk);

        liq.revokeRole(liq.KEEPER_ROLE(), cfg.oldAdmin);

        vm.stopBroadcast();

        _requireLacksRole(
            liq.hasRole(liq.KEEPER_ROLE(), cfg.oldAdmin),
            "PHASE_B_KEEPER_REVOKE",
            "legacy keeper removed from LiquidationEngine"
        );

        console2.log("PHASE_B_KEEPER_REVOKE   : PASS");
        vm.startBroadcast(pk);

        nxusd.revokeRole(nxusd.DEFAULT_ADMIN_ROLE(), cfg.oldAdmin);
        oracle.revokeRole(oracle.DEFAULT_ADMIN_ROLE(), cfg.oldAdmin);
        vault.revokeRole(vault.DEFAULT_ADMIN_ROLE(), cfg.oldAdmin);
        liq.revokeRole(liq.DEFAULT_ADMIN_ROLE(), cfg.oldAdmin);

        vm.stopBroadcast();

        _requireLacksRole(
            nxusd.hasRole(nxusd.DEFAULT_ADMIN_ROLE(), cfg.oldAdmin),
            "PHASE_C_ADMIN_REVOKE",
            "legacy admin removed from NXUSDToken"
        );
        _requireLacksRole(
            oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), cfg.oldAdmin),
            "PHASE_C_ADMIN_REVOKE",
            "legacy admin removed from OracleModule"
        );
        _requireLacksRole(
            vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), cfg.oldAdmin),
            "PHASE_C_ADMIN_REVOKE",
            "legacy admin removed from VaultManager"
        );
        _requireLacksRole(
            liq.hasRole(liq.DEFAULT_ADMIN_ROLE(), cfg.oldAdmin),
            "PHASE_C_ADMIN_REVOKE",
            "legacy admin removed from LiquidationEngine"
        );

        console2.log("PHASE_C_ADMIN_REVOKE    : PASS");
        _requireHasRole(
            vault.hasRole(vault.GUARDIAN_ROLE(), cfg.newGuardian),
            "FINAL_VERIFY",
            "new guardian still active on VaultManager"
        );
        _requireHasRole(
            liq.hasRole(liq.GUARDIAN_ROLE(), cfg.newGuardian),
            "FINAL_VERIFY",
            "new guardian still active on LiquidationEngine"
        );
        _requireHasRole(
            liq.hasRole(liq.KEEPER_ROLE(), cfg.newKeeper),
            "FINAL_VERIFY",
            "new keeper still active on LiquidationEngine"
        );
        _requireHasRole(
            nxusd.hasRole(nxusd.DEFAULT_ADMIN_ROLE(), cfg.newAdmin),
            "FINAL_VERIFY",
            "new admin still active on NXUSDToken"
        );
        _requireHasRole(
            oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), cfg.newAdmin),
            "FINAL_VERIFY",
            "new admin still active on OracleModule"
        );
        _requireHasRole(
            vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), cfg.newAdmin),
            "FINAL_VERIFY",
            "new admin still active on VaultManager"
        );
        _requireHasRole(
            liq.hasRole(liq.DEFAULT_ADMIN_ROLE(), cfg.newAdmin),
            "FINAL_VERIFY",
            "new admin still active on LiquidationEngine"
        );

        console2.log("FINAL_VERIFY              : PASS");
        console2.log("==================================================");
        console2.log("GOVERNANCE REVOKE SCENARIO RESULT: PASS");
        console2.log("==================================================");
    }

    function _loadConfig() internal view returns (Config memory cfg) {
        cfg.nxusdToken = vm.envAddress("NXUSD_TOKEN");
        cfg.oracleModule = vm.envAddress("ORACLE_MODULE");
        cfg.vaultManager = vm.envAddress("VAULT_MANAGER");
        cfg.liquidationEngine = vm.envAddress("LIQUIDATION_ENGINE");
        cfg.oldAdmin = vm.envAddress("OLD_ADMIN");
        cfg.newAdmin = vm.envAddress("NEW_ADMIN");
        cfg.newGuardian = vm.envAddress("NEW_GUARDIAN");
        cfg.newKeeper = vm.envAddress("NEW_KEEPER");
    }

    function _validateConfig(Config memory cfg) internal view {
        if (cfg.nxusdToken == address(0)) revert ZeroAddress("NXUSD_TOKEN");
        if (cfg.oracleModule == address(0)) revert ZeroAddress("ORACLE_MODULE");
        if (cfg.vaultManager == address(0)) revert ZeroAddress("VAULT_MANAGER");
        if (cfg.liquidationEngine == address(0)) revert ZeroAddress("LIQUIDATION_ENGINE");
        if (cfg.oldAdmin == address(0)) revert ZeroAddress("OLD_ADMIN");
        if (cfg.newAdmin == address(0)) revert ZeroAddress("NEW_ADMIN");
        if (cfg.newGuardian == address(0)) revert ZeroAddress("NEW_GUARDIAN");
        if (cfg.newKeeper == address(0)) revert ZeroAddress("NEW_KEEPER");

        _validateIsContract("NXUSD_TOKEN", cfg.nxusdToken);
        _validateIsContract("ORACLE_MODULE", cfg.oracleModule);
        _validateIsContract("VAULT_MANAGER", cfg.vaultManager);
        _validateIsContract("LIQUIDATION_ENGINE", cfg.liquidationEngine);
    }

    function _validateIsContract(string memory label, address account) internal view {
        if (account.code.length == 0) revert NotAContract(label, account);
    }

    function _requireHasRole(bool ok, string memory phase, string memory item) internal pure {
        if (!ok) revert ScenarioVerificationFailed(phase, item);
    }

    function _requireLacksRole(bool stillHasRole, string memory phase, string memory item) internal pure {
        if (stillHasRole) revert ScenarioVerificationFailed(phase, item);
    }
}
