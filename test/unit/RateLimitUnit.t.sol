// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {L1BridgeTest} from "../L1Bridge.t.sol";
import {L1Bridge} from "../../src/L1Bridge.sol";

contract RateLimitUnitTest is L1BridgeTest {
    // Новая константа для тестов
    uint256 public constant TEST_TX_LIMIT = 5 ether; // maxBridgeLimit
    
    /// @notice Test global rate limit reached
    function test_RateLimit_Revert_GlobalLimit() public {
        uint256 amount = TEST_TX_LIMIT; // 5 ETH, не 10 ETH

        // Fill global limit - нужно 20 транзакций по 5 ETH = 100 ETH
        for (uint256 i = 0; i < 20; i++) {
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
        vm.startPrank(alice);

        // Две транзакции по 5 ETH = 10 ETH (personal limit)
        bridge.bridge{value: TEST_TX_LIMIT}(address(0)); // 5 ETH
        bridge.bridge{value: TEST_TX_LIMIT}(address(0)); // еще 5 ETH, всего 10

        // Try to exceed user limit
        vm.expectRevert(L1Bridge.PersonalDailyRateLimitReached.selector);
        bridge.bridge{value: 0.1 ether}(address(0));

        vm.stopPrank();
    }

    /// @notice Test global limit resets after new day
    function test_RateLimit_GlobalReset() public {
        // Fill global limit (20 транзакций по 5 ETH)
        for (uint256 i = 0; i < 20; i++) {
            address user = address(uint160(i + 100));
            vm.deal(user, TEST_TX_LIMIT);
            vm.prank(user);
            bridge.bridge{value: TEST_TX_LIMIT}(address(0));
        }

        // Warp to next day
        _warpToNewDay();

        // Should succeed now
        vm.prank(alice);
        bridge.bridge{value: TEST_TX_LIMIT}(address(0));

        assertEq(bridge.totalBridgedToday(), TEST_TX_LIMIT);
    }

    /// @notice Test user limit resets after new day
    function test_RateLimit_UserReset() public {
        vm.startPrank(alice);

        // Fill user limit (2 транзакции по 5 ETH)
        bridge.bridge{value: TEST_TX_LIMIT}(address(0));
        bridge.bridge{value: TEST_TX_LIMIT}(address(0));

        // Warp to next day
        _warpToNewDay();

        // Should succeed now
        bridge.bridge{value: TEST_TX_LIMIT}(address(0));

        assertEq(bridge.usersDailyRateLimits(alice), TEST_TX_LIMIT);

        vm.stopPrank();
    }

    /// @notice Test edge case - bridging exactly at user limit
    function test_RateLimit_ExactUserLimit() public {
        vm.startPrank(alice);
        
        bridge.bridge{value: TEST_TX_LIMIT}(address(0)); // 5 ETH
        bridge.bridge{value: TEST_TX_LIMIT}(address(0)); // еще 5 ETH, всего 10
        
        assertEq(bridge.usersDailyRateLimits(alice), 10 ether);
        vm.stopPrank();
    }

    /// @notice Test edge case - bridging exactly at global limit
    function test_RateLimit_ExactGlobalLimit() public {
        // 20 пользователей по 5 ETH = 100 ETH
        for (uint256 i = 0; i < 20; i++) {
            address user = address(uint160(i + 100));
            vm.deal(user, TEST_TX_LIMIT);
            vm.prank(user);
            bridge.bridge{value: TEST_TX_LIMIT}(address(0));
        }

        assertEq(bridge.totalBridgedToday(), DAILY_LIMIT);
    }
}
