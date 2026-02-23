// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {L1Bridge} from "../src/L1Bridge.sol";

contract DeployL1 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address relayer = vm.envAddress("RELAYER_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        L1Bridge l1Bridge = new L1Bridge();
        console.log("=================================");
        console.log("L1Bridge deployed at:", address(l1Bridge));
        console.log("Network: Sepolia");
        console.log("Owner:", l1Bridge.owner());

        l1Bridge.setRelayer(relayer);
        console.log("Relayer set to:", relayer);
        console.log("=================================");

        vm.stopBroadcast();
    }
}
