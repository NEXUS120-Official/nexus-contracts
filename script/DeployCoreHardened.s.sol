// HARDENED CORE DEPLOY SCRIPT
// Canonical purpose:
// - preserve deploy logic compatibility with DeployCore.s.sol
// - provide separate historical track for hardened core redeploy
// - support governance capability-aligned live deployment

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

import {NXUSDToken} from "../src/core/NXUSDToken.sol";
import {OracleModule} from "../src/oracle/OracleModule.sol";
import {VaultManager} from "../src/vault/VaultManager.sol";
import {LiquidationEngine} from "../src/vault/LiquidationEngine.sol";

contract DeployCoreHardenedScript is Script {
    struct DeployConfig {
        address admin;
        address oracleFeed;
        address collateralToken;
        address keeper;
        address guardian;
        uint256 oracleMaxDelay;
        uint256 vaultMaxDelay;
        uint256 minCollateralRatioBps;
        uint256 liquidationRatioBps;
        uint256 closeFactorBps;
    }

    function loadConfig() internal view returns (DeployConfig memory cfg) {
        cfg.admin = vm.envAddress("ADMIN");
        cfg.oracleFeed = vm.envAddress("ORACLE_FEED");
        cfg.collateralToken = vm.envAddress("COLLATERAL_TOKEN");
        cfg.keeper = vm.envAddress("KEEPER");
        cfg.guardian = vm.envAddress("GUARDIAN");

        cfg.oracleMaxDelay = vm.envUint("ORACLE_MAX_DELAY");
        cfg.vaultMaxDelay = vm.envUint("VAULT_MAX_DELAY");
        cfg.minCollateralRatioBps = vm.envUint("MIN_COLLATERAL_RATIO_BPS");
        cfg.liquidationRatioBps = vm.envUint("LIQUIDATION_RATIO_BPS");
        cfg.closeFactorBps = vm.envUint("CLOSE_FACTOR_BPS");
    }

    function run() external {
        uint256 deployerPk = vm.envUint("PRIVATE_KEY");
        DeployConfig memory cfg = loadConfig();

        vm.startBroadcast(deployerPk);

        NXUSDToken nxusd = new NXUSDToken(cfg.admin);

        OracleModule oracle = new OracleModule(cfg.admin, cfg.oracleFeed, cfg.oracleMaxDelay);

        VaultManager vault = new VaultManager(
            cfg.admin,
            cfg.collateralToken,
            address(nxusd),
            address(oracle),
            cfg.minCollateralRatioBps,
            cfg.liquidationRatioBps,
            cfg.vaultMaxDelay
        );

        LiquidationEngine liq = new LiquidationEngine(cfg.admin, address(nxusd), address(vault), cfg.closeFactorBps);

        nxusd.setMinter(address(vault), true);
        nxusd.setBurner(address(vault), true);

        vault.grantRole(vault.KEEPER_ROLE(), address(liq));
        liq.grantRole(liq.KEEPER_ROLE(), cfg.keeper);

        vault.grantRole(vault.GUARDIAN_ROLE(), cfg.guardian);
        liq.grantRole(liq.GUARDIAN_ROLE(), cfg.guardian);

        vm.stopBroadcast();

        require(nxusd.hasRole(nxusd.MINTER_ROLE(), address(vault)), "post-deploy: vault missing MINTER_ROLE");
        require(nxusd.hasRole(nxusd.BURNER_ROLE(), address(vault)), "post-deploy: vault missing BURNER_ROLE");
        require(vault.hasRole(vault.GUARDIAN_ROLE(), cfg.guardian), "post-deploy: guardian missing on vault");
        require(liq.hasRole(liq.GUARDIAN_ROLE(), cfg.guardian), "post-deploy: guardian missing on liquidation engine");
        require(liq.hasRole(liq.KEEPER_ROLE(), cfg.keeper), "post-deploy: keeper missing on liquidation engine");
        require(!vault.paused(), "post-deploy: vault unexpectedly paused");
        require(!liq.paused(), "post-deploy: liquidation engine unexpectedly paused");

        console2.log("=== NEXUS CORE HARDENED DEPLOYED ===");
        console2.log("NXUSDToken        :", address(nxusd));
        console2.log("OracleModule      :", address(oracle));
        console2.log("VaultManager      :", address(vault));
        console2.log("LiquidationEngine :", address(liq));

        console2.log("Admin             :", cfg.admin);
        console2.log("Keeper            :", cfg.keeper);
        console2.log("Guardian          :", cfg.guardian);
        console2.log("Oracle Feed       :", cfg.oracleFeed);
        console2.log("Collateral Token  :", cfg.collateralToken);
        console2.log("Vault paused      :", vault.paused());
        console2.log("Liq paused        :", liq.paused());
        console2.log("POST-DEPLOY ASSERT :", "PASS");
    }
}
