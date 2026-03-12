// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";

import {NXUSDToken} from "../src/core/NXUSDToken.sol";
import {OracleModule} from "../src/oracle/OracleModule.sol";
import {VaultManager} from "../src/vault/VaultManager.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {MockAggregatorV3} from "./mocks/MockAggregatorV3.sol";

contract VaultPauseTest is Test {
    address admin = address(0xA11CE);
    address user = address(0xD00D);
    address guardian = address(0xBEEF);

    MockERC20 weth;
    NXUSDToken nxusd;
    MockAggregatorV3 feed;
    OracleModule oracle;
    VaultManager vault;

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    function setUp() public {
        weth = new MockERC20("Wrapped Ether", "WETH");

        vm.prank(admin);
        nxusd = new NXUSDToken(admin);

        feed = new MockAggregatorV3(8);
        feed.setRoundData(2000_00000000, block.timestamp);

        vm.prank(admin);
        oracle = new OracleModule(admin, address(feed), 1 hours);

        vm.prank(admin);
        vault = new VaultManager(admin, address(weth), address(nxusd), address(oracle), 15000, 13000, 1 hours);

        vm.prank(admin);
        nxusd.setMinter(address(vault), true);

        vm.prank(admin);
        nxusd.setBurner(address(vault), true);

        bytes32 guardianRole = vault.GUARDIAN_ROLE();

        vm.prank(admin);
        vault.grantRole(guardianRole, guardian);

        weth.mint(user, 10 ether);

        vm.prank(user);
        weth.approve(address(vault), type(uint256).max);
    }

    function testGuardianCanPauseVault() public {
        vm.prank(guardian);
        vault.pause();

        assertTrue(vault.paused());
    }

    function testNonGuardianCannotPauseVault() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, user, vault.GUARDIAN_ROLE()));

        vm.prank(user);
        vault.pause();
    }

    function testAdminCanUnpauseVault() public {
        vm.prank(guardian);
        vault.pause();

        vm.prank(admin);
        vault.unpause();

        assertFalse(vault.paused());
    }

    function testPauseBlocksDeposit() public {
        vm.prank(guardian);
        vault.pause();

        vm.expectRevert();
        vm.prank(user);
        vault.deposit(1 ether);
    }

    function testPauseBlocksMint() public {
        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(guardian);
        vault.pause();

        vm.expectRevert();
        vm.prank(user);
        vault.mint(1000e18);
    }
}
