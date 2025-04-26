// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {BettingApp} from "../src/BettingApp.sol";
import {TestToken} from "../src/TestToken.sol";
import {console} from "forge-std/console.sol";

contract DeployBettingApp is Script {
    function run() public {
        // Load the deployer's private key from the environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy TestToken with an initial supply of 1,000,000 tokens (18 decimals)
        TestToken testToken = new TestToken(1_000_000 * 10 ** 18);

        BettingApp bettingApp = new BettingApp(address(testToken));

        // Log deployed addresses
        console.log("TestToken deployed to:", address(testToken));
        console.log("BettingApp deployed to:", address(bettingApp));

        vm.stopBroadcast();
    }
}
