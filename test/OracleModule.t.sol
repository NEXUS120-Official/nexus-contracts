// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import {OracleModule} from "../src/oracle/OracleModule.sol";
import {MockAggregatorV3} from "./mocks/MockAggregatorV3.sol";

contract OracleModuleTest is Test {

    OracleModule oracle;
    MockAggregatorV3 feed;

    address admin = address(0xA11CE);
    address user  = address(0xD00D);

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    function setUp() public {
        feed = new MockAggregatorV3(8);

        feed.setRoundData(100_000_000, block.timestamp);

        vm.prank(admin);
        oracle = new OracleModule(admin, address(feed), 1 hours);
    }

    function testNonAdminCannotSetFeed() public {

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                user,
                bytes32(0)
            )
        );

        vm.prank(user);
        oracle.setFeed(address(feed));
    }

    function testNonAdminCannotSetMaxDelay() public {

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                user,
                bytes32(0)
            )
        );

        vm.prank(user);
        oracle.setMaxDelay(2 hours);
    }

    function testGetPriceRevertsOnNonPositivePrice() public {

        feed.setRoundData(0, block.timestamp);

        vm.expectRevert(bytes("ORACLE: price <= 0"));
        oracle.getPrice();
    }

    function testGetPriceRevertsOnStale() public {

        vm.warp(block.timestamp + 2 hours);

        vm.expectRevert(bytes("ORACLE: stale"));
        oracle.getPrice();
    }

    function testGetPriceHappyPath() public {

        (uint256 price, uint256 updatedAt, uint8 decimals) = oracle.getPrice();

        assertEq(price, 100_000_000);
        assertEq(updatedAt, block.timestamp);
        assertEq(decimals, 8);
    }

}
