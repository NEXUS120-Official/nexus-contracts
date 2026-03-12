// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMockERC20 {
    function mint(address to, uint256 amt) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IMockFeed {
    function setRoundData(int256 answer_, uint256 updatedAt_) external;
}

interface IVaultManager {
    function deposit(uint256 amount) external;
    function mint(uint256 amount) external;
    function debtOf(address account) external view returns (uint256);
    function collateralOf(address account) external view returns (uint256);
}

interface ILiquidationEngine {
    function executeLiquidation(address account, uint256 repayAmount) external returns (uint256 seizeAmount);
}

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract SmokeScenario is Script {
    struct SmokeAddresses {
        address admin;
        address keeper;
        address mockCollateral;
        address mockFeed;
        address nxusd;
        address vault;
        address liquidationEngine;
    }

    function loadConfig() internal view returns (SmokeAddresses memory cfg) {
        cfg.admin = vm.envAddress("ADMIN");
        cfg.keeper = vm.envAddress("KEEPER");
        cfg.mockCollateral = vm.envAddress("SMOKE_MOCK_COLLATERAL");
        cfg.mockFeed = vm.envAddress("SMOKE_MOCK_FEED");
        cfg.nxusd = vm.envAddress("SMOKE_NXUSD");
        cfg.vault = vm.envAddress("SMOKE_VAULT");
        cfg.liquidationEngine = vm.envAddress("SMOKE_LIQUIDATION_ENGINE");
    }

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        SmokeAddresses memory cfg = loadConfig();

        IMockERC20 collateral = IMockERC20(cfg.mockCollateral);
        IMockFeed feed = IMockFeed(cfg.mockFeed);
        IERC20Like nxusd = IERC20Like(cfg.nxusd);
        IVaultManager vault = IVaultManager(cfg.vault);
        ILiquidationEngine liq = ILiquidationEngine(cfg.liquidationEngine);

        vm.startBroadcast(pk);

        collateral.mint(cfg.admin, 10 ether);
        collateral.approve(cfg.vault, type(uint256).max);

        vault.deposit(2 ether);
        vault.mint(2000e18);

        feed.setRoundData(1200_00000000, block.timestamp);

        nxusd.approve(cfg.liquidationEngine, 1000e18);
        uint256 seized = liq.executeLiquidation(cfg.admin, 1000e18);

        vm.stopBroadcast();

        console2.log("=== NEXUS SMOKE SCENARIO COMPLETE ===");
        console2.log("Seized collateral :", seized);
        console2.log("Admin NXUSD bal   :", nxusd.balanceOf(cfg.admin));
        console2.log("Admin COL bal     :", collateral.balanceOf(cfg.admin));
        console2.log("Vault debt        :", vault.debtOf(cfg.admin));
        console2.log("Vault collateral  :", vault.collateralOf(cfg.admin));
    }
}
