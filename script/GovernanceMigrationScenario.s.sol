// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IAccessControlScenarioLike {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function grantRole(bytes32 role, address account) external;
}

interface IScenarioNXUSDLike is IAccessControlScenarioLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

interface IScenarioOracleLike is IAccessControlScenarioLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

interface IScenarioVaultLike is IAccessControlScenarioLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function GUARDIAN_ROLE() external view returns (bytes32);
}

interface IScenarioLiqLike is IAccessControlScenarioLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function GUARDIAN_ROLE() external view returns (bytes32);
    function KEEPER_ROLE() external view returns (bytes32);
}

contract GovernanceMigrationScenarioScript is Script {
    error ZeroAddress(string label);
    error NotAContract(string label, address account);
    error ScenarioVerificationFailed(string phase, string item);

    struct Config {
        address nxusdToken;
        address oracleModule;
        address vaultManager;
        address liquidationEngine;
        address newAdmin;
        address newGuardian;
        address newKeeper;
    }

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        Config memory cfg = _loadConfig();
        _validateConfig(cfg);

        IScenarioNXUSDLike nxusd = IScenarioNXUSDLike(cfg.nxusdToken);
        IScenarioOracleLike oracle = IScenarioOracleLike(cfg.oracleModule);
        IScenarioVaultLike vault = IScenarioVaultLike(cfg.vaultManager);
        IScenarioLiqLike liq = IScenarioLiqLike(cfg.liquidationEngine);

        console2.log("==================================================");
        console2.log("NEXUS CONTRACTS - GOVERNANCE MIGRATION SCENARIO");
        console2.log("==================================================");
        console2.log("NXUSDToken        :", cfg.nxusdToken);
        console2.log("OracleModule      :", cfg.oracleModule);
        console2.log("VaultManager      :", cfg.vaultManager);
        console2.log("LiquidationEngine :", cfg.liquidationEngine);
        console2.log("New Admin         :", cfg.newAdmin);
        console2.log("New Guardian      :", cfg.newGuardian);
        console2.log("New Keeper        :", cfg.newKeeper);
        console2.log("==================================================");
        vm.startBroadcast(pk);

        vault.grantRole(vault.GUARDIAN_ROLE(), cfg.newGuardian);
        liq.grantRole(liq.GUARDIAN_ROLE(), cfg.newGuardian);

        liq.grantRole(liq.KEEPER_ROLE(), cfg.newKeeper);

        nxusd.grantRole(nxusd.DEFAULT_ADMIN_ROLE(), cfg.newAdmin);
        oracle.grantRole(oracle.DEFAULT_ADMIN_ROLE(), cfg.newAdmin);
        vault.grantRole(vault.DEFAULT_ADMIN_ROLE(), cfg.newAdmin);
        liq.grantRole(liq.DEFAULT_ADMIN_ROLE(), cfg.newAdmin);

        vm.stopBroadcast();

        _requireHasRole(
            vault.hasRole(vault.GUARDIAN_ROLE(), cfg.newGuardian), "PHASE_A_GUARDIAN", "VaultManager guardian grant"
        );
        _requireHasRole(
            liq.hasRole(liq.GUARDIAN_ROLE(), cfg.newGuardian), "PHASE_A_GUARDIAN", "LiquidationEngine guardian grant"
        );

        _requireHasRole(
            liq.hasRole(liq.KEEPER_ROLE(), cfg.newKeeper), "PHASE_B_KEEPER", "LiquidationEngine keeper grant"
        );

        _requireHasRole(
            nxusd.hasRole(nxusd.DEFAULT_ADMIN_ROLE(), cfg.newAdmin), "PHASE_C_ADMIN", "NXUSDToken admin grant"
        );
        _requireHasRole(
            oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), cfg.newAdmin), "PHASE_C_ADMIN", "OracleModule admin grant"
        );

        _requireHasRole(
            vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), cfg.newAdmin), "PHASE_C_ADMIN", "VaultManager admin grant"
        );

        _requireHasRole(
            liq.hasRole(liq.DEFAULT_ADMIN_ROLE(), cfg.newAdmin), "PHASE_C_ADMIN", "LiquidationEngine admin grant"
        );

        console2.log("PHASE_A_GUARDIAN : PASS");
        console2.log("PHASE_B_KEEPER   : PASS");
        console2.log("PHASE_C_ADMIN    : PASS");
        console2.log("==================================================");
        console2.log("GOVERNANCE MIGRATION SCENARIO RESULT: PASS");
        console2.log("==================================================");
    }

    function _loadConfig() internal view returns (Config memory cfg) {
        cfg.nxusdToken = vm.envAddress("NXUSD_TOKEN");
        cfg.oracleModule = vm.envAddress("ORACLE_MODULE");
        cfg.vaultManager = vm.envAddress("VAULT_MANAGER");
        cfg.liquidationEngine = vm.envAddress("LIQUIDATION_ENGINE");
        cfg.newAdmin = vm.envAddress("NEW_ADMIN");
        cfg.newGuardian = vm.envAddress("NEW_GUARDIAN");
        cfg.newKeeper = vm.envAddress("NEW_KEEPER");
    }

    function _validateConfig(Config memory cfg) internal view {
        if (cfg.nxusdToken == address(0)) revert ZeroAddress("NXUSD_TOKEN");
        if (cfg.oracleModule == address(0)) revert ZeroAddress("ORACLE_MODULE");
        if (cfg.vaultManager == address(0)) revert ZeroAddress("VAULT_MANAGER");
        if (cfg.liquidationEngine == address(0)) revert ZeroAddress("LIQUIDATION_ENGINE");
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
}
