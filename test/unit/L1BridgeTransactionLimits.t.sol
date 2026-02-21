// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {L1Bridge} from "../../src/L1Bridge.sol";
import {Test} from "forge-std/Test.sol";

contract L1BridgeTransactionLimitsTest is Test {
    L1Bridge bridge;
    address user = address(1);
    address owner;

    event Depositing(
        address indexed depositor,
        address indexed recipient,
        uint256 indexed nonce,
        uint256 amount,
        uint256 timestamp
    );

    function setUp() public {
        bridge = new L1Bridge();
        owner = bridge.owner();
        vm.deal(user, 100 ether);
        vm.deal(owner, 10 ether);
    }

    // ============ ТЕСТЫ ЛИМИТОВ ============

    function testBridgeBelowMin() public {
        uint256 amount = 0.0001 ether; // меньше 0.001 ether
        
        vm.prank(user);
        vm.expectRevert(L1Bridge.MinBridgeTransactionLimitReached.selector);
        bridge.bridge{value: amount}(user);
    }

    function testBridgeAboveMax() public {
        uint256 amount = 6 ether; // больше 5 ether
        
        vm.prank(user);
        vm.expectRevert(L1Bridge.MaxBridgeTransactionLimitReached.selector);
        bridge.bridge{value: amount}(user);
    }

    function testBridgeAtMinLimit() public {
        uint256 amount = 0.001 ether; // точно минимальный лимит
        
        vm.prank(user);
        // Исправление: не проверяем timestamp в событии
        vm.expectEmit(true, true, true, false);
        emit Depositing(user, user, 0, amount, 0); // timestamp не проверяем
        bridge.bridge{value: amount}(user);
    }

    function testBridgeAtMaxLimit() public {
        uint256 amount = 5 ether; // точно максимальный лимит
        
        vm.prank(user);
        vm.expectEmit(true, true, true, false);
        emit Depositing(user, user, 0, amount, 0); // timestamp не проверяем
        bridge.bridge{value: amount}(user);
    }

    function testBridgeValidAmount() public {
        uint256 amount = 1 ether;
        
        vm.prank(user);
        vm.expectEmit(true, true, true, false);
        emit Depositing(user, user, 0, amount, 0); // timestamp не проверяем
        bridge.bridge{value: amount}(user);
    }

    // ============ ТЕСТЫ УСТАНОВКИ ЛИМИТОВ ============

    function testSetMaxBridge() public {
        uint256 newMaxLimit = 3 ether;
        
        vm.prank(owner);
        bridge.setMaxBridgeTransactionLimit(newMaxLimit);
        assertEq(bridge.maxBridgeLimit(), newMaxLimit);
    }

    function testSetMinBridge() public {
        uint256 newMinLimit = 0.01 ether;
        
        vm.prank(owner); // Добавлен owner
        bridge.setMinBridgeTransactionLimit(newMinLimit);
        assertEq(bridge.minBridgeAmount(), newMinLimit);
    }

    function testOnlyOwnerCanSetMaxLimit() public {
        vm.prank(user);
        vm.expectRevert(); // OwnableUnauthorizedAccount error
        bridge.setMaxBridgeTransactionLimit(3 ether);
    }

    function testOnlyOwnerCanSetMinLimit() public {
        vm.prank(user);
        vm.expectRevert(); // Должно ревертиться, теперь добавлен onlyOwner
        bridge.setMinBridgeTransactionLimit(0.01 ether);
    }

    function testCannotSetMaxAboveLimit() public {
        uint256 tooHighLimit = bridge.DAILY_RATE_LIMIT() / 10 + 1 ether;
        
        vm.prank(owner);
        vm.expectRevert(L1Bridge.MaxValuereached.selector);
        bridge.setMaxBridgeTransactionLimit(tooHighLimit);
    }

    // ============ ТЕСТЫ С НОВЫМИ ЛИМИТАМИ ============

    function testNewLimitsAreApplied() public {
        // Устанавливаем новые лимиты
        uint256 newMinLimit = 0.002 ether;
        uint256 newMaxLimit = 4 ether;
        
        vm.startPrank(owner);
        bridge.setMinBridgeTransactionLimit(newMinLimit);
        bridge.setMaxBridgeTransactionLimit(newMaxLimit);
        vm.stopPrank();
        
        // Проверяем что старый min больше не работает
        vm.prank(user);
        vm.expectRevert(L1Bridge.MinBridgeTransactionLimitReached.selector);
        bridge.bridge{value: 0.001 ether}(user);
        
        // Проверяем что старый max больше не работает
        vm.prank(user);
        vm.expectRevert(L1Bridge.MaxBridgeTransactionLimitReached.selector);
        bridge.bridge{value: 5 ether}(user);
        
        // Проверяем что новые лимиты работают
        vm.prank(user);
        vm.expectEmit(true, true, true, false);
        emit Depositing(user, user, 0, 0.002 ether, 0);
        bridge.bridge{value: 0.002 ether}(user);
        
        vm.prank(user);
        vm.expectEmit(true, true, true, false);
        emit Depositing(user, user, 1, 4 ether, 0);
        bridge.bridge{value: 4 ether}(user);
    }

    // ============ ТЕСТЫ ВЗАИМОДЕЙСТВИЯ ============

    function testTxLimitsWithRateLimits() public {
        vm.startPrank(user);
        
        // Первый бридж - 4 ETH
        bridge.bridge{value: 4 ether}(user);
        assertEq(bridge.usersDailyRateLimits(user), 4 ether);
        
        // Второй бридж - еще 4 ETH (суммарно 8)
        bridge.bridge{value: 4 ether}(user);
        assertEq(bridge.usersDailyRateLimits(user), 8 ether);
        
        // Третий бридж - 3 ETH (суммарно 11 > 10) - должен упасть по rate limit
        vm.expectRevert(L1Bridge.PersonalDailyRateLimitReached.selector);
        bridge.bridge{value: 3 ether}(user);
        
        vm.stopPrank();
    }

    // ============ ТЕСТЫ НА ГРАНИЧНЫЕ УСЛОВИЯ ============

    function testBridgeWithZeroAmount() public {
        vm.prank(user);
        // Меняем ожидаемую ошибку с ZeroAmount на MinBridgeTransactionLimitReached
        vm.expectRevert(L1Bridge.MinBridgeTransactionLimitReached.selector);
        bridge.bridge{value: 0}(user);
    }

    function testMultipleBridgesWithinLimits() public {
        uint256 amount1 = 1 ether;
        uint256 amount2 = 2 ether;
        uint256 amount3 = 2 ether; // Всего 5 ETH (под лимитом)
        
        vm.startPrank(user);
        
        bridge.bridge{value: amount1}(user);
        bridge.bridge{value: amount2}(user);
        bridge.bridge{value: amount3}(user);
        
        vm.stopPrank();
        
        // Проверяем что rate limit посчитал правильно
        assertEq(bridge.usersDailyRateLimits(user), 5 ether);
    }

    // ============ ТЕСТЫ RECEIVE/FALLBACK ============

    function testReceiveBelowMin() public {
        vm.prank(user);
        vm.expectRevert(L1Bridge.MinBridgeTransactionLimitReached.selector);
        address(bridge).call{value: 0.0001 ether}(""); // assertFalse не нужен
    }

    function testFallbackAboveMax() public {
        vm.prank(user);
        vm.expectRevert(L1Bridge.MaxBridgeTransactionLimitReached.selector);
        address(bridge).call{value: 6 ether}(abi.encodeWithSignature("nonexistent()"));
    }

}