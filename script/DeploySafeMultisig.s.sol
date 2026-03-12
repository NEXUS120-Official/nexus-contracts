// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

import {Safe} from "safe-smart-account/contracts/Safe.sol";
import {SafeProxyFactory} from "safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import {SafeProxy} from "safe-smart-account/contracts/proxies/SafeProxy.sol";

contract DeploySafeMultisigScript is Script {
    error ZeroAddress(string label);
    error InvalidThreshold(uint256 threshold);
    error DuplicateOwner(address owner);
    error DeploymentFailed(string item);

    struct Config {
        address owner1;
        address owner2;
        address owner3;
        address owner4;
        address owner5;
        address owner6;
        address owner7;
        uint256 threshold;
        uint256 saltNonce;
    }

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        Config memory cfg = _loadConfig();
        _validateConfig(cfg);

        address[7] memory fixedOwners =
            [cfg.owner1, cfg.owner2, cfg.owner3, cfg.owner4, cfg.owner5, cfg.owner6, cfg.owner7];

        address[] memory owners = _ownersArray(fixedOwners);

        console2.log("==================================================");
        console2.log("NEXUS CONTRACTS - SAFE MULTISIG DEPLOY");
        console2.log("==================================================");
        console2.log("Threshold        :", cfg.threshold);
        console2.log("Salt Nonce       :", cfg.saltNonce);
        console2.log("Owner 1          :", cfg.owner1);
        console2.log("Owner 2          :", cfg.owner2);
        console2.log("Owner 3          :", cfg.owner3);
        console2.log("Owner 4          :", cfg.owner4);
        console2.log("Owner 5          :", cfg.owner5);
        console2.log("Owner 6          :", cfg.owner6);
        console2.log("Owner 7          :", cfg.owner7);
        console2.log("==================================================");

        vm.startBroadcast(pk);

        Safe singleton = new Safe();
        SafeProxyFactory factory = new SafeProxyFactory();

        bytes memory initializer = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners,
            cfg.threshold,
            address(0),
            bytes(""),
            address(0),
            address(0),
            0,
            payable(address(0))
        );

        SafeProxy proxy = factory.createProxyWithNonce(address(singleton), initializer, cfg.saltNonce);

        vm.stopBroadcast();

        address safeProxy = address(proxy);

        if (address(singleton).code.length == 0) revert DeploymentFailed("SAFE_SINGLETON_CODE");
        if (address(factory).code.length == 0) revert DeploymentFailed("SAFE_FACTORY_CODE");
        if (safeProxy.code.length == 0) revert DeploymentFailed("SAFE_PROXY_CODE");

        console2.log("SAFE_SINGLETON    :", address(singleton));
        console2.log("SAFE_FACTORY      :", address(factory));
        console2.log("SAFE_PROXY        :", safeProxy);
        console2.log("DEPLOY_RESULT     : PASS");
        console2.log("==================================================");
    }

    function _loadConfig() internal view returns (Config memory cfg) {
        cfg.owner1 = vm.envAddress("SAFE_OWNER_1");
        cfg.owner2 = vm.envAddress("SAFE_OWNER_2");
        cfg.owner3 = vm.envAddress("SAFE_OWNER_3");
        cfg.owner4 = vm.envAddress("SAFE_OWNER_4");
        cfg.owner5 = vm.envAddress("SAFE_OWNER_5");
        cfg.owner6 = vm.envAddress("SAFE_OWNER_6");
        cfg.owner7 = vm.envAddress("SAFE_OWNER_7");
        cfg.threshold = vm.envUint("SAFE_THRESHOLD");

        if (vm.envOr("SAFE_SALT_NONCE", uint256(0)) == 0) {
            cfg.saltNonce = uint256(
                keccak256(
                    abi.encode(
                        block.chainid,
                        cfg.threshold,
                        cfg.owner1,
                        cfg.owner2,
                        cfg.owner3,
                        cfg.owner4,
                        cfg.owner5,
                        cfg.owner6,
                        cfg.owner7
                    )
                )
            );
        } else {
            cfg.saltNonce = vm.envUint("SAFE_SALT_NONCE");
        }
    }

    function _validateConfig(Config memory cfg) internal pure {
        if (cfg.owner1 == address(0)) revert ZeroAddress("SAFE_OWNER_1");
        if (cfg.owner2 == address(0)) revert ZeroAddress("SAFE_OWNER_2");
        if (cfg.owner3 == address(0)) revert ZeroAddress("SAFE_OWNER_3");
        if (cfg.owner4 == address(0)) revert ZeroAddress("SAFE_OWNER_4");
        if (cfg.owner5 == address(0)) revert ZeroAddress("SAFE_OWNER_5");
        if (cfg.owner6 == address(0)) revert ZeroAddress("SAFE_OWNER_6");
        if (cfg.owner7 == address(0)) revert ZeroAddress("SAFE_OWNER_7");

        if (cfg.threshold != 4) revert InvalidThreshold(cfg.threshold);

        _requireDistinct(cfg.owner1, cfg.owner2);
        _requireDistinct(cfg.owner1, cfg.owner3);
        _requireDistinct(cfg.owner1, cfg.owner4);
        _requireDistinct(cfg.owner1, cfg.owner5);
        _requireDistinct(cfg.owner1, cfg.owner6);
        _requireDistinct(cfg.owner1, cfg.owner7);

        _requireDistinct(cfg.owner2, cfg.owner3);
        _requireDistinct(cfg.owner2, cfg.owner4);
        _requireDistinct(cfg.owner2, cfg.owner5);
        _requireDistinct(cfg.owner2, cfg.owner6);
        _requireDistinct(cfg.owner2, cfg.owner7);

        _requireDistinct(cfg.owner3, cfg.owner4);
        _requireDistinct(cfg.owner3, cfg.owner5);
        _requireDistinct(cfg.owner3, cfg.owner6);
        _requireDistinct(cfg.owner3, cfg.owner7);

        _requireDistinct(cfg.owner4, cfg.owner5);
        _requireDistinct(cfg.owner4, cfg.owner6);
        _requireDistinct(cfg.owner4, cfg.owner7);

        _requireDistinct(cfg.owner5, cfg.owner6);
        _requireDistinct(cfg.owner5, cfg.owner7);

        _requireDistinct(cfg.owner6, cfg.owner7);
    }

    function _ownersArray(address[7] memory fixedOwners) internal pure returns (address[] memory owners) {
        owners = new address[](7);

        for (uint256 i = 0; i < 7; i++) {
            owners[i] = fixedOwners[i];
        }
    }

    function _requireDistinct(address a, address b) internal pure {
        if (a == b) revert DuplicateOwner(a);
    }
}
