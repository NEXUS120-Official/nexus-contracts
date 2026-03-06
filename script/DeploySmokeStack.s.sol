// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

import {MockERC20} from "../test/mocks/MockERC20.sol";
import {MockAggregatorV3} from "../test/mocks/MockAggregatorV3.sol";

import {NXUSDToken} from "../src/core/NXUSDToken.sol";
import {OracleModule} from "../src/oracle/OracleModule.sol";
import {VaultManager} from "../src/vault/VaultManager.sol";
import {LiquidationEngine} from "../src/vault/LiquidationEngine.sol";

contract DeploySmokeStack is Script {
    struct SmokeConfig {
        address admin;
        address keeper;
        uint256 oracleMaxDelay;
        uint256 vaultMaxDelay;
        uint256 minCollateralRatioBps;
        uint256 liquidationRatioBps;
        uint256 closeFactorBps;
        uint8 oracleDecimals;
        int256 initialPrice;
    }

    function loadConfig() internal view returns (SmokeConfig memory cfg) {
        cfg.admin = vm.envAddress("ADMIN");
        cfg.keeper = vm.envAddress("KEEPER");

        cfg.oracleMaxDelay = 3600;
        cfg.vaultMaxDelay = 3600;
        cfg.minCollateralRatioBps = 15000;
        cfg.liquidationRatioBps = 13000;
        cfg.closeFactorBps = 5000;
        cfg.oracleDecimals = 8;
        cfg.initialPrice = 2000_00000000;
    }

    function run() external {
        uint256 deployerPk = vm.envUint("PRIVATE_KEY");
        SmokeConfig memory cfg = loadConfig();

        vm.startBroadcast(deployerPk);

        MockERC20 collateral = new MockERC20("Wrapped Ether Mock", "WETHm");
        MockAggregatorV3 feed = new MockAggregatorV3(cfg.oracleDecimals);
        feed.setRoundData(cfg.initialPrice, block.timestamp);

        NXUSDToken nxusd = new NXUSDToken(cfg.admin);

        OracleModule oracle = new OracleModule(
            cfg.admin,
            address(feed),
            cfg.oracleMaxDelay
        );

        VaultManager vault = new VaultManager(
            cfg.admin,
            address(collateral),
            address(nxusd),
            address(oracle),
            cfg.minCollateralRatioBps,
            cfg.liquidationRatioBps,
            cfg.vaultMaxDelay
        );

        LiquidationEngine liq = new LiquidationEngine(
            cfg.admin,
            address(nxusd),
            address(vault),
            cfg.closeFactorBps
        );

        nxusd.setMinter(address(vault), true);
        nxusd.setBurner(address(vault), true);

        bytes32 vaultKeeperRole = vault.KEEPER_ROLE();
        bytes32 liqKeeperRole = liq.KEEPER_ROLE();

        vault.grantRole(vaultKeeperRole, address(liq));
        liq.grantRole(liqKeeperRole, cfg.keeper);

        vm.stopBroadcast();

        console2.log("=== NEXUS SMOKE STACK DEPLOYED ===");
        console2.log("MockCollateral     :", address(collateral));
        console2.log("MockFeed           :", address(feed));
        console2.log("NXUSDToken         :", address(nxusd));
        console2.log("OracleModule       :", address(oracle));
        console2.log("VaultManager       :", address(vault));
        console2.log("LiquidationEngine  :", address(liq));
        console2.log("Admin              :", cfg.admin);
        console2.log("Keeper             :", cfg.keeper);
    }
}
