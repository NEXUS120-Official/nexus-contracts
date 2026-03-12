// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Safe} from "safe-smart-account/contracts/Safe.sol";
import {Enum} from "safe-smart-account/contracts/libraries/Enum.sol";

contract SafeExecGrantVaultKeeperScript is Script {
    address constant SAFE_ADDR = 0x8626240187bb366a8566D338b84a7F84f237164F;
    address constant VAULT_MANAGER = 0xF09AAD220C6c4d805cF6cE5561B546f51ADFBb03;
    address constant KEEPER = 0x8150dbba9F0960300a360033882685ca450a7038;
    bytes32 constant KEEPER_ROLE = 0xfc8737ab85eb45125971625a9ebdb75cc78e01d5c1fa80c4c6e5203f47bc4fab;

    struct Sig {
        address owner;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function run() external {
        Safe safe = Safe(payable(SAFE_ADDR));

        uint256 pk1 = vm.envUint("SAFE_SIGNER_PK_1");
        uint256 pk2 = vm.envUint("SAFE_SIGNER_PK_2");
        uint256 pk3 = vm.envUint("SAFE_SIGNER_PK_3");
        uint256 pk4 = vm.envUint("SAFE_SIGNER_PK_4");

        address owner1 = vm.addr(pk1);
        address owner2 = vm.addr(pk2);
        address owner3 = vm.addr(pk3);
        address owner4 = vm.addr(pk4);

        console2.log("SAFE          :", SAFE_ADDR);
        console2.log("VAULT_MANAGER :", VAULT_MANAGER);
        console2.log("KEEPER        :", KEEPER);
        console2.log("OWNER_1       :", owner1);
        console2.log("OWNER_2       :", owner2);
        console2.log("OWNER_3       :", owner3);
        console2.log("OWNER_4       :", owner4);

        bytes memory data = abi.encodeWithSignature(
            "grantRole(bytes32,address)",
            KEEPER_ROLE,
            KEEPER
        );

        uint256 nonce = safe.nonce();

        bytes32 txHash = safe.getTransactionHash(
            VAULT_MANAGER,
            0,
            data,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            nonce
        );

        console2.logBytes32(txHash);

        bytes memory signatures = _buildSignatures(txHash, pk1, pk2, pk3, pk4);

        vm.startBroadcast(pk1);

        bool ok = safe.execTransaction(
            VAULT_MANAGER,
            0,
            data,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            signatures
        );

        vm.stopBroadcast();

        require(ok, "SAFE_EXEC_FAILED");

        console2.log("SAFE_EXEC_RESULT: PASS");
    }

    function _buildSignatures(
        bytes32 txHash,
        uint256 pk1,
        uint256 pk2,
        uint256 pk3,
        uint256 pk4
    ) internal view returns (bytes memory) {
        Sig memory s1 = _sign(txHash, pk1);
        Sig memory s2 = _sign(txHash, pk2);
        Sig memory s3 = _sign(txHash, pk3);
        Sig memory s4 = _sign(txHash, pk4);

        Sig[4] memory arr = [s1, s2, s3, s4];
        _sort(arr);

        return abi.encodePacked(
            arr[0].r, arr[0].s, bytes1(arr[0].v),
            arr[1].r, arr[1].s, bytes1(arr[1].v),
            arr[2].r, arr[2].s, bytes1(arr[2].v),
            arr[3].r, arr[3].s, bytes1(arr[3].v)
        );
    }

    function _sign(bytes32 txHash, uint256 pk) internal view returns (Sig memory out) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, txHash);
        out.owner = vm.addr(pk);
        out.v = v;
        out.r = r;
        out.s = s;
    }

    function _sort(Sig[4] memory arr) internal pure {
        for (uint256 i = 0; i < arr.length; i++) {
            for (uint256 j = i + 1; j < arr.length; j++) {
                if (arr[j].owner < arr[i].owner) {
                    Sig memory tmp = arr[i];
                    arr[i] = arr[j];
                    arr[j] = tmp;
                }
            }
        }
    }
}
