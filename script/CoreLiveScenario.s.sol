// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20Live {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IVaultLive {
    function deposit(uint256 amount) external;
    function mint(uint256 amount) external;
    function debtOf(address account) external view returns (uint256);
    function collateralOf(address account) external view returns (uint256);
    function minCollateralRatioBps() external view returns (uint256);
    function liquidationRatioBps() external view returns (uint256);
}

interface IOracleLive {
    function getPrice() external view returns (uint256 price, uint256 updatedAt, uint8 decimals);
}

contract CoreLiveScenario is Script {
    struct LiveConfig {
        address admin;
        address collateralToken;
        address nxusd;
        address oracle;
        address vault;
        uint256 depositAmount;
        uint256 mintAmount;
    }

    function loadConfig() internal view returns (LiveConfig memory cfg) {
        cfg.admin = vm.envAddress("ADMIN");
        cfg.collateralToken = vm.envAddress("COLLATERAL_TOKEN");
        cfg.nxusd = vm.envAddress("CORE_NXUSD");
        cfg.oracle = vm.envAddress("CORE_ORACLE");
        cfg.vault = vm.envAddress("CORE_VAULT");
        cfg.depositAmount = vm.envUint("CORE_SCENARIO_DEPOSIT_AMOUNT");
        cfg.mintAmount = vm.envUint("CORE_SCENARIO_MINT_AMOUNT");
    }

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        LiveConfig memory cfg = loadConfig();

        IERC20Live collateral = IERC20Live(cfg.collateralToken);
        IERC20Live nxusd = IERC20Live(cfg.nxusd);
        IOracleLive oracle = IOracleLive(cfg.oracle);
        IVaultLive vault = IVaultLive(cfg.vault);

        (uint256 price, uint256 updatedAt, uint8 oracleDecimals) = oracle.getPrice();

        require(cfg.depositAmount > 0, "LIVE: deposit is zero");
        require(cfg.mintAmount > 0, "LIVE: mint is zero");
        require(collateral.balanceOf(cfg.admin) >= cfg.depositAmount, "LIVE: insufficient collateral balance");

        vm.startBroadcast(pk);

        require(collateral.approve(cfg.vault, type(uint256).max), "LIVE: approve failed");
        vault.deposit(cfg.depositAmount);
        vault.mint(cfg.mintAmount);

        vm.stopBroadcast();

        console2.log("=== NEXUS CORE LIVE SCENARIO COMPLETE ===");
        console2.log("Admin              :", cfg.admin);
        console2.log("Collateral Token   :", cfg.collateralToken);
        console2.log("NXUSD Token        :", cfg.nxusd);
        console2.log("Oracle             :", cfg.oracle);
        console2.log("Vault              :", cfg.vault);
        console2.log("Oracle Price       :", price);
        console2.log("Oracle UpdatedAt   :", updatedAt);
        console2.log("Oracle Decimals    :", uint256(oracleDecimals));
        console2.log("Deposit Amount     :", cfg.depositAmount);
        console2.log("Mint Amount        :", cfg.mintAmount);
        console2.log("Admin COL Balance  :", collateral.balanceOf(cfg.admin));
        console2.log("Admin NXUSD Balance:", nxusd.balanceOf(cfg.admin));
        console2.log("Vault Debt         :", vault.debtOf(cfg.admin));
        console2.log("Vault Collateral   :", vault.collateralOf(cfg.admin));
        console2.log("Vault MinCR Bps    :", vault.minCollateralRatioBps());
        console2.log("Vault LiqCR Bps    :", vault.liquidationRatioBps());
    }
}
