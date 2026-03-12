// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import {NXUSDToken} from "../src/core/NXUSDToken.sol";

contract NXUSDTokenTest is Test {
    NXUSDToken token;

    address admin = address(0xA11CE);
    address minter = address(0xBEEF);
    address burner = address(0xCAFE);
    address user = address(0xD00D);

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    function setUp() public {
        vm.prank(admin);
        token = new NXUSDToken(admin);
    }

    function testMintRevertsWithoutRole() public {
        uint256 amt = 100e18;

        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, user, token.MINTER_ROLE()));

        vm.prank(user);
        token.mint(user, amt);
    }

    function testBurnRevertsWithoutRole() public {
        uint256 amt = 50e18;

        vm.prank(admin);
        token.setMinter(minter, true);

        vm.prank(minter);
        token.mint(user, amt);

        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, user, token.BURNER_ROLE()));

        vm.prank(user);
        token.burn(user, amt);
    }

    function testAdminSetMinterGrantsAndRevokes() public {
        vm.prank(admin);
        token.setMinter(minter, true);

        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));

        vm.prank(admin);
        token.setMinter(minter, false);

        assertFalse(token.hasRole(token.MINTER_ROLE(), minter));
    }

    function testAdminSetBurnerGrantsAndRevokes() public {
        vm.prank(admin);
        token.setBurner(burner, true);

        assertTrue(token.hasRole(token.BURNER_ROLE(), burner));

        vm.prank(admin);
        token.setBurner(burner, false);

        assertFalse(token.hasRole(token.BURNER_ROLE(), burner));
    }

    function testMintEmitsEventAndUpdatesSupply() public {
        uint256 amt = 123e18;

        vm.prank(admin);
        token.setMinter(minter, true);

        vm.expectEmit(true, true, true, true);
        emit NXUSDMinted(user, amt, minter);

        vm.prank(minter);
        token.mint(user, amt);

        assertEq(token.balanceOf(user), amt);
        assertEq(token.totalSupply(), amt);
    }

    function testBurnEmitsEventAndUpdatesSupply() public {
        uint256 amt = 200e18;

        vm.prank(admin);
        token.setMinter(minter, true);

        vm.prank(admin);
        token.setBurner(burner, true);

        vm.prank(minter);
        token.mint(user, amt);

        vm.expectEmit(true, true, true, true);
        emit NXUSDBurned(user, amt, burner);

        vm.prank(burner);
        token.burn(user, amt);

        assertEq(token.balanceOf(user), 0);
        assertEq(token.totalSupply(), 0);
    }

    event NXUSDMinted(address indexed to, uint256 amount, address indexed by);
    event NXUSDBurned(address indexed from, uint256 amount, address indexed by);

    function testNonAdminCannotSetMinter() public {
        vm.expectRevert();

        vm.prank(user);
        token.setMinter(minter, true);
    }

    function testNonAdminCannotSetBurner() public {
        vm.expectRevert();

        vm.prank(user);
        token.setBurner(burner, true);
    }
}
