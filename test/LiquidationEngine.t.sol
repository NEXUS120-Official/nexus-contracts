// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";

import {NXUSDToken} from "../src/core/NXUSDToken.sol";
import {OracleModule} from "../src/oracle/OracleModule.sol";
import {VaultManager} from "../src/vault/VaultManager.sol";
import {LiquidationEngine} from "../src/vault/LiquidationEngine.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {MockAggregatorV3} from "./mocks/MockAggregatorV3.sol";

contract LiquidationEngineTest is Test {
    address admin = address(0xA11CE);
    address user = address(0xD00D);
    address keeper = address(0xBEEF);

    MockERC20 weth;
    NXUSDToken nxusd;
    MockAggregatorV3 feed;
    OracleModule oracle;
    VaultManager vault;
    LiquidationEngine liq;

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    function setUp() public {
        weth = new MockERC20("Wrapped Ether", "WETH");

        vm.prank(admin);
        nxusd = new NXUSDToken(admin);

        feed = new MockAggregatorV3(8);
        feed.setRoundData(2000_00000000, block.timestamp);

        vm.prank(admin);
        oracle = new OracleModule(admin, address(feed), 1 hours, address(0));

        vm.prank(admin);
        vault = new VaultManager(admin, address(weth), address(nxusd), address(oracle), 15000, 13000, 1 hours);

        vm.prank(admin);
        liq = new LiquidationEngine(admin, address(nxusd), address(vault), 5000);

        vm.prank(admin);
        nxusd.setMinter(address(vault), true);

        vm.prank(admin);
        nxusd.setBurner(address(vault), true);

        bytes32 vaultKeeperRole = vault.KEEPER_ROLE();
        bytes32 liqKeeperRole = liq.KEEPER_ROLE();

        vm.prank(admin);
        vault.grantRole(vaultKeeperRole, address(liq));

        // [TASK 1] Register liq as the canonical liquidation engine so that
        // vault.liquidate() accepts calls from it.
        vm.prank(admin);
        vault.setLiquidationEngine(address(liq));

        vm.prank(admin);
        liq.grantRole(liqKeeperRole, keeper);
        weth.mint(user, 10 ether);

        vm.prank(user);
        weth.approve(address(vault), type(uint256).max);
    }

    function _openUnsafeVault() internal {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(user);
        vault.mint(2000e18);

        // price drop: 2 ETH * $1200 = $2400
        // debt 2000, liq threshold 130% => needs >= 2600, so unsafe
        feed.setRoundData(1200_00000000, block.timestamp);
    }

    function testNonKeeperCannotExecuteLiquidation() public {
        _openUnsafeVault();

        vm.prank(admin);
        nxusd.setMinter(address(this), true);

        nxusd.mint(address(this), 500e18);
        nxusd.approve(address(liq), 500e18);

        bytes32 liqKeeperRole = liq.KEEPER_ROLE();

        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, address(this), liqKeeperRole));

        liq.executeLiquidation(user, 500e18);
    }

    function testHealthyVaultCannotBeLiquidated() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(user);
        vault.mint(1000e18);

        vm.prank(admin);
        nxusd.setMinter(keeper, true);

        vm.prank(keeper);
        nxusd.mint(keeper, 500e18);

        vm.prank(keeper);
        nxusd.approve(address(liq), 500e18);

        vm.expectRevert(bytes("LIQ: vault not liquidatable"));
        vm.prank(keeper);
        liq.executeLiquidation(user, 500e18);
    }

    function testLiquidationRevertsIfExceedsCloseFactor() public {
        _openUnsafeVault();

        vm.prank(admin);
        nxusd.setMinter(keeper, true);

        vm.prank(keeper);
        nxusd.mint(keeper, 1500e18);

        vm.prank(keeper);
        nxusd.approve(address(liq), 1500e18);

        vm.expectRevert(bytes("LIQ: exceeds close factor"));
        vm.prank(keeper);
        liq.executeLiquidation(user, 1200e18);
    }

    function testLiquidationReducesDebtAndTransfersCollateral() public {
        _openUnsafeVault();

        vm.prank(admin);
        nxusd.setMinter(keeper, true);

        vm.prank(keeper);
        nxusd.mint(keeper, 1000e18);

        vm.prank(keeper);
        nxusd.approve(address(liq), 1000e18);

        uint256 keeperWethBefore = weth.balanceOf(keeper);

        vm.prank(keeper);
        uint256 seized = liq.executeLiquidation(user, 1000e18);

        assertGt(seized, 0);
        assertEq(vault.debtOf(user), 1000e18);
        assertEq(weth.balanceOf(keeper), keeperWethBefore + seized);
    }

    function testLiquidatorPaysNxusd() public {
        _openUnsafeVault();

        vm.prank(admin);
        nxusd.setMinter(keeper, true);

        vm.prank(keeper);
        nxusd.mint(keeper, 600e18);

        vm.prank(keeper);
        nxusd.approve(address(liq), 600e18);

        uint256 beforeBal = nxusd.balanceOf(keeper);

        vm.prank(keeper);
        liq.executeLiquidation(user, 600e18);

        assertEq(nxusd.balanceOf(keeper), beforeBal - 600e18);
    }
}
