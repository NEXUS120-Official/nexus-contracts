// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IAccessControlGrantLike {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function grantRole(bytes32 role, address account) external;
}

interface IGrantNXUSDLike is IAccessControlGrantLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

interface IGrantOracleLike is IAccessControlGrantLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

interface IGrantVaultLike is IAccessControlGrantLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

interface IGrantLiqLike is IAccessControlGrantLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

contract MultisigAdminGrantScript is Script {
    error ZeroAddress(string label);
    error NotAContract(string label, address account);
    error ScenarioVerificationFailed(string item);

    struct Config {
        address nxusdToken;
        address oracleModule;
        address vaultManager;
        address liquidationEngine;
        address safeAdmin;
    }
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        Config memory cfg = _loadConfig();
        _validateConfig(cfg);

        IGrantNXUSDLike nxusd = IGrantNXUSDLike(cfg.nxusdToken);
        IGrantOracleLike oracle = IGrantOracleLike(cfg.oracleModule);
        IGrantVaultLike vault = IGrantVaultLike(cfg.vaultManager);
        IGrantLiqLike liq = IGrantLiqLike(cfg.liquidationEngine);

        console2.log("==================================================");
        console2.log("NEXUS CONTRACTS - MULTISIG ADMIN GRANT");
        console2.log("==================================================");
        console2.log("NXUSDToken        :", cfg.nxusdToken);
        console2.log("OracleModule      :", cfg.oracleModule);
        console2.log("VaultManager      :", cfg.vaultManager);
        console2.log("LiquidationEngine :", cfg.liquidationEngine);
        console2.log("Safe Admin        :", cfg.safeAdmin);
        console2.log("==================================================");

        vm.startBroadcast(pk);

        nxusd.grantRole(nxusd.DEFAULT_ADMIN_ROLE(), cfg.safeAdmin);
        oracle.grantRole(oracle.DEFAULT_ADMIN_ROLE(), cfg.safeAdmin);
        vault.grantRole(vault.DEFAULT_ADMIN_ROLE(), cfg.safeAdmin);
        liq.grantRole(liq.DEFAULT_ADMIN_ROLE(), cfg.safeAdmin);

        vm.stopBroadcast();

        _requireHasRole(nxusd.hasRole(nxusd.DEFAULT_ADMIN_ROLE(), cfg.safeAdmin), "NXUSDToken admin grant");
        _requireHasRole(oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), cfg.safeAdmin), "OracleModule admin grant");
        _requireHasRole(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), cfg.safeAdmin), "VaultManager admin grant");
        _requireHasRole(liq.hasRole(liq.DEFAULT_ADMIN_ROLE(), cfg.safeAdmin), "LiquidationEngine admin grant");

        console2.log("PHASE_ADMIN_GRANT : PASS");
        console2.log("==================================================");
        console2.log("MULTISIG ADMIN GRANT RESULT: PASS");
        console2.log("==================================================");
    }
    function _loadConfig() internal view returns (Config memory cfg) {
        cfg.nxusdToken = vm.envAddress("NXUSD_TOKEN");
        cfg.oracleModule = vm.envAddress("ORACLE_MODULE");
        cfg.vaultManager = vm.envAddress("VAULT_MANAGER");
        cfg.liquidationEngine = vm.envAddress("LIQUIDATION_ENGINE");
        cfg.safeAdmin = vm.envAddress("SAFE_ADMIN");
    }

    function _validateConfig(Config memory cfg) internal view {
        if (cfg.nxusdToken == address(0)) revert ZeroAddress("NXUSD_TOKEN");
        if (cfg.oracleModule == address(0)) revert ZeroAddress("ORACLE_MODULE");
        if (cfg.vaultManager == address(0)) revert ZeroAddress("VAULT_MANAGER");
        if (cfg.liquidationEngine == address(0)) revert ZeroAddress("LIQUIDATION_ENGINE");
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
}
