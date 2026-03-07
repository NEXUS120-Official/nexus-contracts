// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {NXUSDToken} from "../src/core/NXUSDToken.sol";
import {OracleModule} from "../src/oracle/OracleModule.sol";
import {VaultManager} from "../src/vault/VaultManager.sol";
import {LiquidationEngine} from "../src/vault/LiquidationEngine.sol";

interface IOracleFeedLike {
    function decimals() external view returns (uint8);
}

contract PostDeployVerify is Script {
    struct VerifyConfig {
        address admin;
        address keeper;
        address collateralToken;
        address oracleFeed;
        address nxusd;
        address oracle;
        address vault;
        address liquidationEngine;
        uint256 oracleMaxDelay;
        uint256 vaultMaxDelay;
        uint256 minCollateralRatioBps;
        uint256 liquidationRatioBps;
        uint256 closeFactorBps;
    }

    function loadConfig() internal view returns (VerifyConfig memory cfg) {
        cfg.admin = vm.envAddress("ADMIN");
        cfg.keeper = vm.envAddress("KEEPER");

        cfg.collateralToken = vm.envAddress("COLLATERAL_TOKEN");
        cfg.oracleFeed = vm.envAddress("ORACLE_FEED");

        cfg.nxusd = vm.envAddress("CORE_NXUSD");
        cfg.oracle = vm.envAddress("CORE_ORACLE");
        cfg.vault = vm.envAddress("CORE_VAULT");
        cfg.liquidationEngine = vm.envAddress("CORE_LIQUIDATION_ENGINE");

        cfg.oracleMaxDelay = vm.envUint("ORACLE_MAX_DELAY");
        cfg.vaultMaxDelay = vm.envUint("VAULT_MAX_DELAY");
        cfg.minCollateralRatioBps = vm.envUint("MIN_COLLATERAL_RATIO_BPS");
        cfg.liquidationRatioBps = vm.envUint("LIQUIDATION_RATIO_BPS");
        cfg.closeFactorBps = vm.envUint("CLOSE_FACTOR_BPS");
    }

    function run() external view {
        VerifyConfig memory cfg = loadConfig();

        require(cfg.admin != address(0), "VERIFY: admin is zero");
        require(cfg.keeper != address(0), "VERIFY: keeper is zero");
        require(cfg.collateralToken != address(0), "VERIFY: collateral token is zero");
        require(cfg.oracleFeed != address(0), "VERIFY: oracle feed is zero");

        require(cfg.nxusd != address(0), "VERIFY: nxusd is zero");
        require(cfg.oracle != address(0), "VERIFY: oracle is zero");
        require(cfg.vault != address(0), "VERIFY: vault is zero");
        require(cfg.liquidationEngine != address(0), "VERIFY: liquidation engine is zero");

        NXUSDToken nxusd = NXUSDToken(cfg.nxusd);
        OracleModule oracle = OracleModule(cfg.oracle);
        VaultManager vault = VaultManager(cfg.vault);
        LiquidationEngine liq = LiquidationEngine(cfg.liquidationEngine);

        require(address(vault.COLLATERAL()) == cfg.collateralToken, "VERIFY: vault collateral mismatch");
        require(address(vault.NXUSD()) == cfg.nxusd, "VERIFY: vault nxusd mismatch");
        require(address(vault.oracle()) == cfg.oracle, "VERIFY: vault oracle mismatch");

        require(vault.maxDelay() == cfg.vaultMaxDelay, "VERIFY: vault maxDelay mismatch");
        require(vault.minCollateralRatioBps() == cfg.minCollateralRatioBps, "VERIFY: vault minCR mismatch");
        require(vault.liquidationRatioBps() == cfg.liquidationRatioBps, "VERIFY: vault liqCR mismatch");

        require(address(oracle.feed()) == cfg.oracleFeed, "VERIFY: oracle feed mismatch");
        require(oracle.maxDelay() == cfg.oracleMaxDelay, "VERIFY: oracle maxDelay mismatch");

        require(address(liq.NXUSD()) == cfg.nxusd, "VERIFY: liq nxusd mismatch");
        require(address(liq.vault()) == cfg.vault, "VERIFY: liq vault mismatch");
        require(liq.closeFactorBps() == cfg.closeFactorBps, "VERIFY: liq close factor mismatch");

        bytes32 minterRole = nxusd.MINTER_ROLE();
        bytes32 burnerRole = nxusd.BURNER_ROLE();
        bytes32 vaultKeeperRole = vault.KEEPER_ROLE();
        bytes32 liqKeeperRole = liq.KEEPER_ROLE();

        require(nxusd.hasRole(minterRole, cfg.vault), "VERIFY: vault not minter");
        require(nxusd.hasRole(burnerRole, cfg.vault), "VERIFY: vault not burner");
        require(vault.hasRole(vaultKeeperRole, cfg.liquidationEngine), "VERIFY: liq engine not vault keeper");
        require(liq.hasRole(liqKeeperRole, cfg.keeper), "VERIFY: keeper not liq keeper");

        console2.log("=== NEXUS CORE POST-DEPLOY VERIFY: PASS ===");
        console2.log("NXUSDToken        :", cfg.nxusd);
        console2.log("OracleModule      :", cfg.oracle);
        console2.log("VaultManager      :", cfg.vault);
        console2.log("LiquidationEngine :", cfg.liquidationEngine);
        console2.log("Collateral Token  :", cfg.collateralToken);
        console2.log("Oracle Feed       :", cfg.oracleFeed);
        console2.log("Admin             :", cfg.admin);
        console2.log("Keeper            :", cfg.keeper);
    }
}
