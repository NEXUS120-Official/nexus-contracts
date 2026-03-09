// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";

import {NXUSDToken} from "../src/core/NXUSDToken.sol";
import {OracleModule} from "../src/oracle/OracleModule.sol";
import {VaultManager} from "../src/vault/VaultManager.sol";
import {LiquidationEngine} from "../src/vault/LiquidationEngine.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {MockAggregatorV3} from "./mocks/MockAggregatorV3.sol";

contract LiquidationPauseTest is Test {
    address admin = address(0xA11CE);
    address user = address(0xD00D);
    address keeper = address(0xBEEF);
    address guardian = address(0xCAFE);

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
        oracle = new OracleModule(admin, address(feed), 1 hours);

        vm.prank(admin);
        vault = new VaultManager(
            admin,
            address(weth),
            address(nxusd),
            address(oracle),
            15000,
            13000,
            1 hours
        );

        vm.prank(admin);
        liq = new LiquidationEngine(
            admin,
            address(nxusd),
            address(vault),
            5000
        );

        vm.prank(admin);
        nxusd.setMinter(address(vault), true);

        vm.prank(admin);
        nxusd.setBurner(address(vault), true);

        bytes32 vaultKeeperRole = vault.KEEPER_ROLE();
        bytes32 liqKeeperRole = liq.KEEPER_ROLE();
        bytes32 liqGuardianRole = liq.GUARDIAN_ROLE();

        vm.prank(admin);
        vault.grantRole(vaultKeeperRole, address(liq));

        vm.prank(admin);
        liq.grantRole(liqKeeperRole, keeper);

        vm.prank(admin);
        liq.grantRole(liqGuardianRole, guardian);

        weth.mint(user, 10 ether);

        vm.prank(user);
        weth.approve(address(vault), type(uint256).max);

        vm.prank(user);
        vault.deposit(2 ether);

        vm.prank(user);
        vault.mint(2000e18);

        feed.setRoundData(1200_00000000, block.timestamp);

        vm.prank(admin);
        nxusd.setMinter(keeper, true);

        vm.prank(keeper);
        nxusd.mint(keeper, 1000e18);

        vm.prank(keeper);
        nxusd.approve(address(liq), 1000e18);
    }

    function testGuardianCanPauseLiquidationEngine() public {
        vm.prank(guardian);
        liq.pause();

        assertTrue(liq.paused());
    }

    function testNonGuardianCannotPauseLiquidationEngine() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                user,
                liq.GUARDIAN_ROLE()
            )
        );

        vm.prank(user);
        liq.pause();
    }

    function testAdminCanUnpauseLiquidationEngine() public {
        vm.prank(guardian);
        liq.pause();

        vm.prank(admin);
        liq.unpause();

        assertFalse(liq.paused());
    }

    function testPauseBlocksExecuteLiquidation() public {
        vm.prank(guardian);
        liq.pause();

        vm.expectRevert();
        vm.prank(keeper);
        liq.executeLiquidation(user, 1000e18);
    }
}
