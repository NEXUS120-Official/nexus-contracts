// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IAccessControlRevokeLike {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function revokeRole(bytes32 role, address account) external;
}

interface IRevokeAdminNXUSDLike is IAccessControlRevokeLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

interface IRevokeAdminOracleLike is IAccessControlRevokeLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

interface IRevokeAdminVaultLike is IAccessControlRevokeLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

interface IRevokeAdminLiqLike is IAccessControlRevokeLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

contract MultisigAdminRevokeScript is Script {
    error ZeroAddress(string label);
    error NotAContract(string label, address account);
    error ScenarioVerificationFailed(string item);

    struct Config {
        address nxusdToken;
        address oracleModule;
        address vaultManager;
        address liquidationEngine;
        address oldAdmin;
        address safeAdmin;
    }
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        Config memory cfg = _loadConfig();
        _validateConfig(cfg);

        IRevokeAdminNXUSDLike nxusd = IRevokeAdminNXUSDLike(cfg.nxusdToken);
        IRevokeAdminOracleLike oracle = IRevokeAdminOracleLike(cfg.oracleModule);
        IRevokeAdminVaultLike vault = IRevokeAdminVaultLike(cfg.vaultManager);
        IRevokeAdminLiqLike liq = IRevokeAdminLiqLike(cfg.liquidationEngine);

        console2.log("==================================================");
        console2.log("NEXUS CONTRACTS - MULTISIG ADMIN REVOKE");
        console2.log("==================================================");
        console2.log("Old Admin         :", cfg.oldAdmin);
        console2.log("Safe Admin        :", cfg.safeAdmin);
        console2.log("==================================================");

        _requireHasRole(nxusd.hasRole(nxusd.DEFAULT_ADMIN_ROLE(), cfg.safeAdmin), "SAFE admin on NXUSDToken");
        _requireHasRole(oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), cfg.safeAdmin), "SAFE admin on OracleModule");
        _requireHasRole(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), cfg.safeAdmin), "SAFE admin on VaultManager");
        _requireHasRole(liq.hasRole(liq.DEFAULT_ADMIN_ROLE(), cfg.safeAdmin), "SAFE admin on LiquidationEngine");

        vm.startBroadcast(pk);

        nxusd.revokeRole(nxusd.DEFAULT_ADMIN_ROLE(), cfg.oldAdmin);
        oracle.revokeRole(oracle.DEFAULT_ADMIN_ROLE(), cfg.oldAdmin);
        vault.revokeRole(vault.DEFAULT_ADMIN_ROLE(), cfg.oldAdmin);
        liq.revokeRole(liq.DEFAULT_ADMIN_ROLE(), cfg.oldAdmin);

        vm.stopBroadcast();

        _requireLacksRole(nxusd.hasRole(nxusd.DEFAULT_ADMIN_ROLE(), cfg.oldAdmin), "OLD admin removed from NXUSDToken");
        _requireLacksRole(oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), cfg.oldAdmin), "OLD admin removed from OracleModule");
        _requireLacksRole(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), cfg.oldAdmin), "OLD admin removed from VaultManager");
        _requireLacksRole(liq.hasRole(liq.DEFAULT_ADMIN_ROLE(), cfg.oldAdmin), "OLD admin removed from LiquidationEngine");

        _requireHasRole(nxusd.hasRole(nxusd.DEFAULT_ADMIN_ROLE(), cfg.safeAdmin), "SAFE retained on NXUSDToken");
        _requireHasRole(oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), cfg.safeAdmin), "SAFE retained on OracleModule");
        _requireHasRole(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), cfg.safeAdmin), "SAFE retained on VaultManager");
        _requireHasRole(liq.hasRole(liq.DEFAULT_ADMIN_ROLE(), cfg.safeAdmin), "SAFE retained on LiquidationEngine");

        console2.log("PHASE_ADMIN_REVOKE : PASS");
        console2.log("==================================================");
        console2.log("MULTISIG ADMIN REVOKE RESULT: PASS");
        console2.log("==================================================");
    }
    function _loadConfig() internal view returns (Config memory cfg) {
        cfg.nxusdToken = vm.envAddress("NXUSD_TOKEN");
        cfg.oracleModule = vm.envAddress("ORACLE_MODULE");
        cfg.vaultManager = vm.envAddress("VAULT_MANAGER");
        cfg.liquidationEngine = vm.envAddress("LIQUIDATION_ENGINE");
        cfg.oldAdmin = vm.envAddress("OLD_ADMIN");
        cfg.safeAdmin = vm.envAddress("SAFE_ADMIN");
    }

    function _validateConfig(Config memory cfg) internal view {
        if (cfg.nxusdToken == address(0)) revert ZeroAddress("NXUSD_TOKEN");
        if (cfg.oracleModule == address(0)) revert ZeroAddress("ORACLE_MODULE");
        if (cfg.vaultManager == address(0)) revert ZeroAddress("VAULT_MANAGER");
        if (cfg.liquidationEngine == address(0)) revert ZeroAddress("LIQUIDATION_ENGINE");
        if (cfg.oldAdmin == address(0)) revert ZeroAddress("OLD_ADMIN");
        if (cfg.safeAdmin == address(0)) revert ZeroAddress("SAFE_ADMIN");

        _validateIsContract("NXUSD_TOKEN", cfg.nxusdToken);
        _validateIsContract("ORACLE_MODULE", cfg.oracleModule);
        _validateIsContract("VAULT_MANAGER", cfg.vaultManager);
        _validateIsContract("LIQUIDATION_ENGINE", cfg.liquidationEngine);
        _validateIsContract("SAFE_ADMIN", cfg.safeAdmin);
    }

    function _validateIsContract(string memory label, address account) internal view {
        if (account.code.length == 0) revert NotAContract(label, account);
    }

    function _requireHasRole(bool ok, string memory item) internal pure {
        if (!ok) revert ScenarioVerificationFailed(item);
    }

    function _requireLacksRole(bool stillHasRole, string memory item) internal pure {
        if (stillHasRole) revert ScenarioVerificationFailed(item);
    }
}
