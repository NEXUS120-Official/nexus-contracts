// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";

import {NXUSDToken} from "../src/core/NXUSDToken.sol";
import {OracleModule} from "../src/oracle/OracleModule.sol";
import {VaultManager} from "../src/vault/VaultManager.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {MockAggregatorV3} from "./mocks/MockAggregatorV3.sol";

contract VaultManagerTest is Test {
    address admin = address(0xA11CE);
    address user = address(0xD00D);

    MockERC20 weth;
    NXUSDToken nxusd;

    MockAggregatorV3 feed;
    OracleModule oracle;

    VaultManager vault;

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
        nxusd.setMinter(address(vault), true);

        vm.prank(admin);
        nxusd.setBurner(address(vault), true);

        weth.mint(user, 10 ether);

        vm.prank(user);
        weth.approve(address(vault), type(uint256).max);
    }

    function testDepositAndWithdraw() public {
        vm.prank(user);
        vault.deposit(2 ether);

        assertEq(vault.collateralOf(user), 2 ether);

        vm.prank(user);
        vault.withdraw(1 ether);

        assertEq(vault.collateralOf(user), 1 ether);
    }

    function testMintFailsWithoutCollateral() public {
        vm.expectRevert(bytes("VAULT: unsafe mint"));

        vm.prank(user);
        vault.mint(1000e18);
    }

    function testMintWithinCollateralization() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(user);
        vault.mint(2000e18);

        assertEq(nxusd.balanceOf(user), 2000e18);
        assertEq(vault.debtOf(user), 2000e18);
    }

    function testWithdrawRevertsIfUnsafe() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(user);
        vault.mint(2000e18);

        vm.expectRevert(bytes("VAULT: unsafe after withdraw"));

        vm.prank(user);
        vault.withdraw(2 ether);
    }

    function testBurnReducesDebt() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(user);
        vault.mint(1000e18);

        vm.prank(user);
        vault.burn(400e18);

        assertEq(vault.debtOf(user), 600e18);
        assertEq(nxusd.balanceOf(user), 600e18);
    }
}
