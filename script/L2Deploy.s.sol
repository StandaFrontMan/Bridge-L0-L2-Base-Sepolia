// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {L2Bridge} from "../src/L2Bridge.sol";

contract DeployL2 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address relayer = vm.envAddress("RELAYER_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        L2Bridge l2Bridge = new L2Bridge();
        console.log("=================================");
        console.log("L2Bridge deployed at:", address(l2Bridge));
        console.log("Network: Base Sepolia");
        console.log("Owner:", l2Bridge.owner());

        l2Bridge.setRelayer(relayer);
        console.log("Relayer set to:", relayer);
        console.log("=================================");

        vm.stopBroadcast();
    }
}
