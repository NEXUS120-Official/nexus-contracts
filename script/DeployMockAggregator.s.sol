// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MockAggregatorV3} from "src/oracle/MockAggregatorV3.sol";

contract DeployMockAggregatorScript is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);

        MockAggregatorV3 mockFeed = new MockAggregatorV3(
            8,
            200102240000
        );

        vm.stopBroadcast();

        console2.log("MOCK_FEED:", address(mockFeed));
    }
}
