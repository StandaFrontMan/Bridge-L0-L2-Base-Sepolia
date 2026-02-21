// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {L1BridgeTest} from "../L1Bridge.t.sol";
import {L1Bridge} from "../../src/L1Bridge.sol";

contract L1BridgePauseTest is L1BridgeTest {
    /// @notice Test that contract starts unpaused
    function test_InitialState_Unpaused() public {
        assertFalse(bridge.paused());
    }

    /// @notice Test that owner can pause the contract
    function test_OwnerCanPause() public {
        vm.prank(owner);
        bridge.changeContractPause();

        assertTrue(bridge.paused());
    }

    /// @notice Test that owner can unpause the contract
    function test_OwnerCanUnpause() public {
        // Сначала ставим на паузу
        vm.prank(owner);
        bridge.changeContractPause();
        assertTrue(bridge.paused());

        // Потом снимаем с паузы
        vm.prank(owner);
        bridge.changeContractPause();
        assertFalse(bridge.paused());
    }

    /// @notice Test that non-owner cannot pause the contract
    function test_NonOwnerCannotPause() public {
        vm.prank(alice);
        vm.expectRevert(); // OwnableUnauthorizedAccount error
        bridge.changeContractPause();

        assertFalse(bridge.paused()); // Состояние не изменилось
    }

    /// @notice Test that bridging reverts when contract is paused
    function test_BridgeReverts_WhenPaused() public {
        uint256 amount = 1 ether;

        // Ставим на паузу
        vm.prank(owner);
        bridge.changeContractPause();

        // Пытаемся сделать бридж
        vm.prank(alice);
        vm.expectRevert(L1Bridge.ContractPaused.selector);
        bridge.bridge{value: amount}(alice);
    }

    /// @notice Test that bridging succeeds when contract is unpaused
    function test_BridgeSucceeds_WhenUnpaused() public {
        uint256 amount = 1 ether;

        // Убеждаемся что не на паузе
        assertFalse(bridge.paused());

        // Делаем бридж
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Depositing(alice, alice, 0, amount, block.timestamp);
        bridge.bridge{value: amount}(alice);

        assertEq(bridge.nonce(), 1);
    }

    /// @notice Test that receive function reverts when contract is paused
    function test_ReceiveReverts_WhenPaused() public {
        uint256 amount = 1 ether;

        // Ставим на паузу
        vm.prank(owner);
        bridge.changeContractPause();

        // Пытаемся отправить через receive
        vm.prank(alice);

        // Убираем expectRevert и проверяем через try/catch
        vm.expectRevert(L1Bridge.ContractPaused.selector);
        address(bridge).call{value: amount}("");

        // assertFalse убираем, так как expectRevert уже проверил ошибку
    }

    /// @notice Test that fallback function reverts when contract is paused
    function test_FallbackReverts_WhenPaused() public {
        uint256 amount = 1 ether;

        // Ставим на паузу
        vm.prank(owner);
        bridge.changeContractPause();

        // Пытаемся отправить через fallback
        vm.prank(alice);
        vm.expectRevert(L1Bridge.ContractPaused.selector);
        address(bridge).call{value: amount}(abi.encodeWithSignature("nonexistent()"));

        // assertFalse убираем
    }

    /// @notice Test that multiple pause/unpause cycles work
    function test_MultiplePauseCycles() public {
        vm.startPrank(owner);

        // Cycle 1: Pause
        bridge.changeContractPause();
        assertTrue(bridge.paused());

        // Cycle 1: Unpause
        bridge.changeContractPause();
        assertFalse(bridge.paused());

        // Cycle 2: Pause
        bridge.changeContractPause();
        assertTrue(bridge.paused());

        // Cycle 2: Unpause
        bridge.changeContractPause();
        assertFalse(bridge.paused());

        vm.stopPrank();
    }

    /// @notice Test that rate limits still work when unpaused
    function test_RateLimitsWork_WhenUnpaused() public {
        uint256 amount = 6 ether; // Больше maxBridgeLimit = 5 ETH

        // Убеждаемся что не на паузе
        assertFalse(bridge.paused());

        // Должен ревертнуться по лимиту, а не по паузе
        vm.prank(alice);
        vm.expectRevert(L1Bridge.MaxBridgeTransactionLimitReached.selector);
        bridge.bridge{value: amount}(alice);
    }

    /// @notice Test that bridge works after pause/unpause cycle
    function test_BridgeWorks_AfterUnpause() public {
        uint256 amount = 1 ether;

        vm.startPrank(owner);
        // Ставим на паузу
        bridge.changeContractPause();
        assertTrue(bridge.paused());

        // Снимаем с паузы
        bridge.changeContractPause();
        assertFalse(bridge.paused());
        vm.stopPrank();

        // Делаем бридж - должен работать
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Depositing(alice, alice, 0, amount, block.timestamp);
        bridge.bridge{value: amount}(alice);

        assertEq(bridge.nonce(), 1);
    }

    /// @notice Test that zero amount reverts with MinBridgeTransactionLimitReached when paused
    function test_ZeroAmount_WhenPaused() public {
        // Ставим на паузу
        vm.prank(owner);
        bridge.changeContractPause();

        // Пытаемся отправить 0 ETH
        vm.prank(alice);
        // Ожидаем ContractPaused, потому что isContractPaused первый
        vm.expectRevert(L1Bridge.ContractPaused.selector);
        bridge.bridge{value: 0}(alice);
    }
}
