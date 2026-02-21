// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {L1Bridge} from "../src/L1Bridge.sol";

contract L1BridgeTest is Test {
    L1Bridge public bridge;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public owner;

    uint256 public constant DAILY_LIMIT = 100 ether;
    uint256 public constant USER_LIMIT = 10 ether; // DAILY_LIMIT / 10
    uint256 public constant INITIAL_BALANCE = 1000 ether;

    event Depositing(
        address indexed depositor, address indexed recipient, uint256 indexed nonce, uint256 amount, uint256 timestamp
    );

    function setUp() public virtual {
        bridge = new L1Bridge();
        owner = bridge.owner();

        // Fund test accounts
        vm.deal(alice, INITIAL_BALANCE);
        vm.deal(bob, INITIAL_BALANCE);
        vm.deal(charlie, INITIAL_BALANCE);
    }

    function _warpToNewDay() internal {
        uint256 today = block.timestamp / 1 days;
        vm.warp((today + 1) * 1 days + 1 hours);
    }
}
