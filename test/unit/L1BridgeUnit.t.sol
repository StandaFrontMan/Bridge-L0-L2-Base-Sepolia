// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {L1BridgeTest} from "../L1Bridge.t.sol";
import {L1Bridge} from "../../src/L1Bridge.sol";

contract BridgeUnitTest is L1BridgeTest {
    /// @notice Test successful bridge with default recipient (address(0))
    function test_Bridge_Success_DefaultRecipient() public {
        uint256 amount = 1 ether;
        uint256 expectedNonce = 0;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Depositing(alice, alice, expectedNonce, amount, block.timestamp);
        bridge.bridge{value: amount}(address(0));

        // Check nonce incremented
        assertEq(bridge.nonce(), expectedNonce + 1);
    }

    /// @notice Test successful bridge with custom recipient
    function test_Bridge_Success_CustomRecipient() public {
        uint256 amount = 1 ether;
        address customRecipient = bob;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Depositing(alice, customRecipient, 0, amount, block.timestamp);
        bridge.bridge{value: amount}(customRecipient);
    }

    /// @notice Test bridge with zero amount reverts
    function test_Bridge_Revert_ZeroAmount() public {
        vm.prank(alice);
        // Исправляем: ожидаем MinBridgeTransactionLimitReached вместо ZeroAmount
        vm.expectRevert(L1Bridge.MinBridgeTransactionLimitReached.selector);
        bridge.bridge{value: 0}(address(0));
    }

    /// @notice Test multiple bridges from same user
    function test_Bridge_MultipleBridges() public {
        uint256 amount1 = 1 ether;
        uint256 amount2 = 2 ether;

        vm.startPrank(alice);

        // First bridge
        vm.expectEmit(true, true, true, true);
        emit Depositing(alice, alice, 0, amount1, block.timestamp);
        bridge.bridge{value: amount1}(address(0));

        // Second bridge
        vm.expectEmit(true, true, true, true);
        emit Depositing(alice, alice, 1, amount2, block.timestamp);
        bridge.bridge{value: amount2}(address(0));

        vm.stopPrank();

        assertEq(bridge.nonce(), 2);
    }

    /// @notice Test receive function
    function test_Receive() public {
        uint256 amount = 1 ether;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Depositing(alice, alice, 0, amount, block.timestamp);
        (bool success,) = address(bridge).call{value: amount}("");
        assertTrue(success);
    }

    /// @notice Test fallback function
    function test_Fallback() public {
        uint256 amount = 1 ether;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Depositing(alice, alice, 0, amount, block.timestamp);
        (bool success,) = address(bridge).call{value: amount}(abi.encodeWithSignature("nonExistingFunction()"));
        assertTrue(success);
    }

    /// @notice Test bridge from multiple users
    function test_Bridge_MultipleUsers() public {
        uint256 aliceAmount = 1 ether;
        uint256 bobAmount = 2 ether;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Depositing(alice, alice, 0, aliceAmount, block.timestamp);
        bridge.bridge{value: aliceAmount}(address(0));

        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Depositing(bob, bob, 1, bobAmount, block.timestamp);
        bridge.bridge{value: bobAmount}(address(0));

        assertEq(bridge.nonce(), 2);
    }
}
