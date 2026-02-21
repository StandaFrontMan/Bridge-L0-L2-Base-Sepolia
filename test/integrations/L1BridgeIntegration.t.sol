// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {L1BridgeTest} from "../L1Bridge.t.sol";
import {L1Bridge} from "../../src/L1Bridge.sol";

contract BridgeIntegrationTest is L1BridgeTest {
    /// @notice Test complete bridge flow with multiple users over multiple days
    function test_Integration_CompleteFlow() public {
        // Day 1: Multiple users bridge
        vm.startPrank(alice);
        bridge.bridge{value: 5 ether}(bob); // Alice bridges to Bob
        vm.stopPrank();

        vm.prank(bob);
        bridge.bridge{value: 3 ether}(charlie); // Bob bridges to Charlie

        vm.prank(charlie);
        bridge.bridge{value: 2 ether}(address(0)); // Charlie bridges to self

        assertEq(bridge.nonce(), 3);
        assertEq(bridge.totalBridgedToday(), 10 ether);

        // Day 2: New day, new bridges
        _warpToNewDay();

        vm.prank(alice);
        bridge.bridge{value: 7 ether}(address(0));

        assertEq(bridge.totalBridgedToday(), 7 ether);
        assertEq(bridge.usersDailyRateLimits(alice), 7 ether);

        // Day 3: Try to exceed limit across days
        _warpToNewDay();

        vm.startPrank(alice);

        // Should be able to use full limit again
        bridge.bridge{value: USER_LIMIT}(address(0));

        vm.expectRevert(L1Bridge.PersonalDailyRateLimitReached.selector);
        bridge.bridge{value: 0.1 ether}(address(0));

        vm.stopPrank();
    }

    /// @notice Test rate limits with real-world scenario
    function test_Integration_RealWorldScenario() public {
        // Morning: Small bridges
        vm.prank(alice);
        bridge.bridge{value: 1 ether}(address(0));

        vm.prank(bob);
        bridge.bridge{value: 2 ether}(address(0));

        // Afternoon: Medium bridges
        vm.prank(charlie);
        bridge.bridge{value: 4 ether}(address(0));

        vm.prank(alice);
        bridge.bridge{value: 3 ether}(address(0));

        // Evening: Large bridge from new user
        address david = makeAddr("david");
        vm.deal(david, USER_LIMIT);
        vm.prank(david);
        bridge.bridge{value: 8 ether}(address(0));

        // Check final state
        assertEq(bridge.usersDailyRateLimits(alice), 4 ether); // 1 + 3
        assertEq(bridge.usersDailyRateLimits(bob), 2 ether);
        assertEq(bridge.usersDailyRateLimits(charlie), 4 ether);
        assertEq(bridge.usersDailyRateLimits(david), 8 ether);
        assertEq(bridge.totalBridgedToday(), 18 ether);
    }

    /// @notice Test bridging to different recipients affects limits correctly
    function test_Integration_DifferentRecipients() public {
        vm.startPrank(alice);

        // Bridge to self
        bridge.bridge{value: 3 ether}(address(0));
        assertEq(bridge.usersDailyRateLimits(alice), 3 ether);

        // Bridge to Bob - still counts against Alice's limit
        bridge.bridge{value: 4 ether}(bob);
        assertEq(bridge.usersDailyRateLimits(alice), 7 ether);

        vm.stopPrank();

        // Bob bridges to self
        vm.prank(bob);
        bridge.bridge{value: 2 ether}(address(0));
        assertEq(bridge.usersDailyRateLimits(bob), 2 ether);
        assertEq(bridge.totalBridgedToday(), 9 ether);
    }
}
