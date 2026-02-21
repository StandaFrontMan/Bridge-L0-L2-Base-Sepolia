// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {L1BridgeTest} from "../L1Bridge.t.sol";
import {L1Bridge} from "../../src/L1Bridge.sol";

contract BridgeIntegrationTest is L1BridgeTest {
    uint256 public constant MAX_TX_LIMIT = 5 ether; // maxBridgeLimit из контракта

    /// @notice Test complete bridge flow with multiple users over multiple days
    function test_Integration_CompleteFlow() public {
        // Day 1: Multiple users bridge (все суммы ≤ 5 ETH)
        vm.startPrank(alice);
        bridge.bridge{value: 4 ether}(bob); // Alice bridges to Bob (4 ETH)
        vm.stopPrank();

        vm.prank(bob);
        bridge.bridge{value: 3 ether}(charlie); // Bob bridges to Charlie (3 ETH)

        vm.prank(charlie);
        bridge.bridge{value: 2 ether}(address(0)); // Charlie bridges to self (2 ETH)

        assertEq(bridge.nonce(), 3);
        assertEq(bridge.totalBridgedToday(), 9 ether); // 4+3+2=9 ETH

        // Day 2: New day, new bridges
        _warpToNewDay();

        vm.prank(alice);
        bridge.bridge{value: 5 ether}(address(0)); // 5 ETH (максимум)

        assertEq(bridge.totalBridgedToday(), 5 ether);
        assertEq(bridge.usersDailyRateLimits(alice), 5 ether);

        // Day 3: Try to exceed limit across days
        _warpToNewDay();

        vm.startPrank(alice);

        // Две транзакции по 5 ETH = 10 ETH (personal limit)
        bridge.bridge{value: 5 ether}(address(0));
        bridge.bridge{value: 5 ether}(address(0));

        // Попытка превысить лимит
        vm.expectRevert(L1Bridge.PersonalDailyRateLimitReached.selector);
        bridge.bridge{value: 0.1 ether}(address(0));

        vm.stopPrank();
    }

    /// @notice Test rate limits with real-world scenario
    function test_Integration_RealWorldScenario() public {
        // Morning: Small bridges (все ≤ 5 ETH)
        vm.prank(alice);
        bridge.bridge{value: 1 ether}(address(0));

        vm.prank(bob);
        bridge.bridge{value: 2 ether}(address(0));

        // Afternoon: Medium bridges
        vm.prank(charlie);
        bridge.bridge{value: 4 ether}(address(0)); // 4 ETH

        vm.prank(alice);
        bridge.bridge{value: 3 ether}(address(0)); // 3 ETH

        // Evening: Large bridge from new user (но ≤ 5 ETH)
        address david = makeAddr("david");
        vm.deal(david, 10 ether);
        vm.prank(david);
        bridge.bridge{value: 5 ether}(address(0)); // 5 ETH (максимум)

        // Еще одна транзакция от David (достигаем 10 ETH)
        vm.prank(david);
        bridge.bridge{value: 5 ether}(address(0)); // еще 5 ETH

        // Check final state
        assertEq(bridge.usersDailyRateLimits(alice), 4 ether); // 1 + 3
        assertEq(bridge.usersDailyRateLimits(bob), 2 ether);
        assertEq(bridge.usersDailyRateLimits(charlie), 4 ether);
        assertEq(bridge.usersDailyRateLimits(david), 10 ether); // 5 + 5
        assertEq(bridge.totalBridgedToday(), 20 ether); // 4+2+4+5+5=20? Нет, пересчитаем:
        // alice: 1+3=4
        // bob: 2=2
        // charlie: 4=4
        // david: 5+5=10
        // Итого: 4+2+4+10 = 20 ETH
    }

    /// @notice Test bridging to different recipients affects limits correctly
    function test_Integration_DifferentRecipients() public {
        vm.startPrank(alice);

        // Bridge to self
        bridge.bridge{value: 3 ether}(address(0));
        assertEq(bridge.usersDailyRateLimits(alice), 3 ether);

        // Bridge to Bob - still counts against Alice's limit
        bridge.bridge{value: 4 ether}(bob); // 4 ETH (всего 7)
        assertEq(bridge.usersDailyRateLimits(alice), 7 ether);

        vm.stopPrank();

        // Bob bridges to self
        vm.prank(bob);
        bridge.bridge{value: 2 ether}(address(0));
        assertEq(bridge.usersDailyRateLimits(bob), 2 ether);
        assertEq(bridge.totalBridgedToday(), 9 ether); // 3+4+2=9
    }
}
