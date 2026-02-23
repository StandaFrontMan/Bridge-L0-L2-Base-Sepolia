// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {L1Bridge} from "../../src/L1Bridge.sol";

contract L1BridgeTest is Test {
    L1Bridge public bridge;

    address public owner = address(this);
    address public relayer = address(0x1);
    address public user = address(0x2);
    address public attacker = address(0x3);

    function setUp() public {
        bridge = new L1Bridge();
        bridge.setRelayer(relayer);
        vm.deal(address(bridge), 10 ether);
    }

    // ═══════════════════════════════════════════════════════════
    // ТЕСТ 1: Успешный withdraw
    // ═══════════════════════════════════════════════════════════
    function testWithdrawSuccess() public {
        uint256 amount = 1 ether;
        uint256 nonce = 1;

        uint256 balanceBefore = user.balance;

        vm.prank(relayer);
        bridge.withdraw(user, amount, nonce);

        uint256 balanceAfter = user.balance;

        assertEq(balanceAfter, balanceBefore + amount);

        assertTrue(bridge.processedWithdrawals(nonce));
    }

    // ═══════════════════════════════════════════════════════════
    // ТЕСТ 2: Withdraw эмитит событие
    // ═══════════════════════════════════════════════════════════
    function testWithdrawEmitsEvent() public {
        uint256 amount = 1 ether;
        uint256 nonce = 1;

        vm.expectEmit(true, true, true, true);
        emit L1Bridge.Withdrawn(user, amount, nonce, block.timestamp);

        vm.prank(relayer);
        bridge.withdraw(user, amount, nonce);
    }

    // ═══════════════════════════════════════════════════════════
    // ТЕСТ 3: Не-relayer не может вызвать withdraw
    // ═══════════════════════════════════════════════════════════
    function testWithdrawRevertsIfNotRelayer() public {
        uint256 amount = 1 ether;
        uint256 nonce = 1;

        vm.expectRevert(L1Bridge.Unauthorized.selector);
        vm.prank(attacker);
        bridge.withdraw(user, amount, nonce);
    }

    // ═══════════════════════════════════════════════════════════
    // ТЕСТ 4: Нельзя использовать один nonce дважды
    // ═══════════════════════════════════════════════════════════
    function testWithdrawRevertsIfNonceAlreadyProcessed() public {
        uint256 amount = 1 ether;
        uint256 nonce = 1;

        vm.prank(relayer);
        bridge.withdraw(user, amount, nonce);

        vm.expectRevert(L1Bridge.AlreadyProcessedWithdraw.selector);
        vm.prank(relayer);
        bridge.withdraw(user, amount, nonce);
    }

    // ═══════════════════════════════════════════════════════════
    // ТЕСТ 5: Revert если недостаточно ETH на контракте
    // ═══════════════════════════════════════════════════════════
    function testWithdrawRevertsIfInsufficientBalance() public {
        uint256 amount = 100 ether; // больше чем на контракте
        uint256 nonce = 1;

        vm.expectRevert(L1Bridge.InsufficientBalanceForWithdraw.selector);
        vm.prank(relayer);
        bridge.withdraw(user, amount, nonce);
    }

    // ═══════════════════════════════════════════════════════════
    // ТЕСТ 6: Withdraw работает когда контракт не на паузе
    // ═══════════════════════════════════════════════════════════
    function testWithdrawRevertsWhenPaused() public {
        uint256 amount = 1 ether;
        uint256 nonce = 1;

        vm.prank(owner);
        bridge.changeContractPause();

        vm.expectRevert(L1Bridge.ContractPaused.selector);
        vm.prank(relayer);
        bridge.withdraw(user, amount, nonce);
    }
}
