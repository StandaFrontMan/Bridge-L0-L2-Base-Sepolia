// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {L1BridgeTest} from "../L1Bridge.t.sol";
import {L1Bridge} from "../../src/L1Bridge.sol";

contract RateLimitUnitTest is L1BridgeTest {
    /// @notice Test global rate limit reached
    function test_RateLimit_Revert_GlobalLimit() public {
        uint256 amount = USER_LIMIT; // 10 ETH

        // Fill global limit with multiple users
        for (uint256 i = 0; i < 10; i++) {
            address user = address(uint160(i + 100));
            vm.deal(user, amount);
            vm.prank(user);
            bridge.bridge{value: amount}(address(0));
        }

        // Try to exceed global limit
        vm.prank(alice);
        vm.expectRevert(L1Bridge.GlobalDailyRateLimitReached.selector);
        bridge.bridge{value: 0.1 ether}(address(0));
    }

    /// @notice Test user rate limit reached
    function test_RateLimit_Revert_UserLimit() public {
        uint256 amount = USER_LIMIT; // 10 ETH

        vm.startPrank(alice);

        // First bridge - should succeed
        bridge.bridge{value: amount}(address(0));

        // Try to exceed user limit
        vm.expectRevert(L1Bridge.PersonalDailyRateLimitReached.selector);
        bridge.bridge{value: 0.1 ether}(address(0));

        vm.stopPrank();
    }

    /// @notice Test global limit resets after new day
    function test_RateLimit_GlobalReset() public {
        // Fill global limit
        for (uint256 i = 0; i < 10; i++) {
            address user = address(uint160(i + 100));
            vm.deal(user, USER_LIMIT);
            vm.prank(user);
            bridge.bridge{value: USER_LIMIT}(address(0));
        }

        // Warp to next day
        _warpToNewDay();

        // Should succeed now
        vm.prank(alice);
        bridge.bridge{value: USER_LIMIT}(address(0));

        assertEq(bridge.totalBridgedToday(), USER_LIMIT);
    }

    /// @notice Test user limit resets after new day
    function test_RateLimit_UserReset() public {
        vm.startPrank(alice);

        // Fill user limit
        bridge.bridge{value: USER_LIMIT}(address(0));

        // Warp to next day
        _warpToNewDay();

        // Should succeed now
        bridge.bridge{value: USER_LIMIT}(address(0));

        assertEq(bridge.usersDailyRateLimits(alice), USER_LIMIT);

        vm.stopPrank();
    }

    /// @notice Test partial user limit usage
    function test_RateLimit_PartialUsage() public {
        uint256 amount1 = 3 ether;
        uint256 amount2 = 3 ether;
        uint256 amount3 = 3 ether; // Total 9 ETH (under 10 ETH limit)

        vm.startPrank(alice);

        bridge.bridge{value: amount1}(address(0));
        assertEq(bridge.usersDailyRateLimits(alice), amount1);

        bridge.bridge{value: amount2}(address(0));
        assertEq(bridge.usersDailyRateLimits(alice), amount1 + amount2);

        bridge.bridge{value: amount3}(address(0));
        assertEq(bridge.usersDailyRateLimits(alice), amount1 + amount2 + amount3);

        vm.stopPrank();
    }

    /// @notice Test multiple users with rate limits
    function test_RateLimit_MultipleUsers() public {
        uint256 amount = 5 ether;

        vm.prank(alice);
        bridge.bridge{value: amount}(address(0));

        vm.prank(bob);
        bridge.bridge{value: amount}(address(0));

        assertEq(bridge.usersDailyRateLimits(alice), amount);
        assertEq(bridge.usersDailyRateLimits(bob), amount);
        assertEq(bridge.totalBridgedToday(), amount * 2);
    }

    /// @notice Test edge case - bridging exactly at user limit
    function test_RateLimit_ExactUserLimit() public {
        vm.prank(alice);
        bridge.bridge{value: USER_LIMIT}(address(0));

        assertEq(bridge.usersDailyRateLimits(alice), USER_LIMIT);
    }

    /// @notice Test edge case - bridging exactly at global limit
    function test_RateLimit_ExactGlobalLimit() public {
        // Use 9 users with full limit + one with partial
        for (uint256 i = 0; i < 9; i++) {
            address user = address(uint160(i + 100));
            vm.deal(user, USER_LIMIT);
            vm.prank(user);
            bridge.bridge{value: USER_LIMIT}(address(0));
        }

        // Last user bridges remaining 10 ETH
        address lastUser = address(uint160(200));
        vm.deal(lastUser, USER_LIMIT);
        vm.prank(lastUser);
        bridge.bridge{value: USER_LIMIT}(address(0));

        assertEq(bridge.totalBridgedToday(), DAILY_LIMIT);
    }
}
