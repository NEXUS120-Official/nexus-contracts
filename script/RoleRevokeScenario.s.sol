// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IAccessControlRevokeLike {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function revokeRole(bytes32 role, address account) external;
}

interface IRoleResolverLike is IAccessControlRevokeLike {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

interface INXUSDRevokeRoleResolverLike is IRoleResolverLike {
    function MINTER_ROLE() external view returns (bytes32);
    function BURNER_ROLE() external view returns (bytes32);
}

interface IVaultRevokeRoleResolverLike is IRoleResolverLike {
    function GUARDIAN_ROLE() external view returns (bytes32);
    function KEEPER_ROLE() external view returns (bytes32);
}

interface ILiquidationRevokeRoleResolverLike is IRoleResolverLike {
    function GUARDIAN_ROLE() external view returns (bytes32);
    function KEEPER_ROLE() external view returns (bytes32);
}

contract RoleRevokeScenarioScript is Script {
    error ZeroAddress(string label);
    error UnsupportedRoleKind(string roleKind);
    error RevokeVerificationFailed(address target, string roleKind, address account);
    error NotAContract(string label, address account);

    struct Config {
        address targetContract;
        address account;
        string roleKind;
    }

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        Config memory cfg = _loadConfig();

        _validateConfig(cfg);

        bytes32 role = _resolveRole(cfg.targetContract, cfg.roleKind);

        console2.log("==================================================");
        console2.log("NEXUS CONTRACTS - ROLE REVOKE SCENARIO");
        console2.log("==================================================");
        console2.log("Target Contract :", cfg.targetContract);
        console2.log("Role Kind       :", cfg.roleKind);
        console2.log("Account         :", cfg.account);
        console2.logBytes32(role);
        console2.log("==================================================");

        bool hadRoleBefore = IAccessControlRevokeLike(cfg.targetContract).hasRole(role, cfg.account);
        console2.log("Pre-revoke has role:", hadRoleBefore);
        vm.startBroadcast(pk);
        IAccessControlRevokeLike(cfg.targetContract).revokeRole(role, cfg.account);
        vm.stopBroadcast();

        bool hasRoleNow = IAccessControlRevokeLike(cfg.targetContract).hasRole(role, cfg.account);
        console2.log("Post-revoke has role:", hasRoleNow);

        if (hasRoleNow) {
            revert RevokeVerificationFailed(cfg.targetContract, cfg.roleKind, cfg.account);
        }

        console2.log("ROLE REVOKE RESULT: PASS");
        console2.log("==================================================");
    }

    function _loadConfig() internal view returns (Config memory cfg) {
        cfg.targetContract = vm.envAddress("TARGET_CONTRACT");
        cfg.account = vm.envAddress("ACCOUNT");
        cfg.roleKind = vm.envString("ROLE_KIND");
    }

    function _validateConfig(Config memory cfg) internal view {
        if (cfg.targetContract == address(0)) revert ZeroAddress("TARGET_CONTRACT");
        if (cfg.account == address(0)) revert ZeroAddress("ACCOUNT");
        _validateIsContract("TARGET_CONTRACT", cfg.targetContract);
    }

    function _validateIsContract(string memory label, address account) internal view {
        if (account.code.length == 0) revert NotAContract(label, account);
    }

    function _resolveRole(address target, string memory roleKind) internal view returns (bytes32) {
        bytes32 h = keccak256(bytes(roleKind));

        if (h == keccak256("ADMIN")) {
            return IRoleResolverLike(target).DEFAULT_ADMIN_ROLE();
        }
        if (h == keccak256("MINTER")) {
            return INXUSDRevokeRoleResolverLike(target).MINTER_ROLE();
        }

        if (h == keccak256("BURNER")) {
            return INXUSDRevokeRoleResolverLike(target).BURNER_ROLE();
        }

        if (h == keccak256("GUARDIAN")) {
            return _resolveGuardianRole(target);
        }

        if (h == keccak256("KEEPER")) {
            return _resolveKeeperRole(target);
        }

        revert UnsupportedRoleKind(roleKind);
    }

    function _resolveGuardianRole(address target) internal view returns (bytes32) {
        (bool ok, bytes memory data) =
            target.staticcall(abi.encodeWithSelector(IVaultRevokeRoleResolverLike.GUARDIAN_ROLE.selector));
        require(ok && data.length == 32, "guardian role not supported");
        return abi.decode(data, (bytes32));
    }

    function _resolveKeeperRole(address target) internal view returns (bytes32) {
        (bool ok, bytes memory data) =
            target.staticcall(abi.encodeWithSelector(IVaultRevokeRoleResolverLike.KEEPER_ROLE.selector));
        require(ok && data.length == 32, "keeper role not supported");
        return abi.decode(data, (bytes32));
    }
}
