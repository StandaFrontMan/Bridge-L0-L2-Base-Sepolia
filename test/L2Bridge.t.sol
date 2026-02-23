// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/L2Bridge.sol";

contract L2BridgeTest is Test {
    L2Bridge public bridge;

    address public owner = makeAddr("owner");
    address public relayer = makeAddr("relayer");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public attacker = makeAddr("attacker");

    // События для проверки
    event RelayerSet(address indexed relayer);
    event Paused();
    event Unpaused();
    event Minted(address indexed minter, uint256 amount, uint256 indexed nonce, uint256 timestamp);
    event Burned(address indexed user, uint256 amount, uint256 indexed nonce, uint256 timestamp);

    function setUp() public {
        // Делаем owner создателем контракта
        vm.startPrank(owner);
        bridge = new L2Bridge();
        bridge.setRelayer(relayer);
        vm.stopPrank();
    }

    // ============ ТЕСТЫ КОНСТРУКТОРА ============

    function test_InitialState() public view {
        assertEq(bridge.owner(), owner, "Owner should be set correctly");
        assertEq(bridge.relayer(), relayer, "Relayer should be set correctly");
        assertFalse(bridge.paused(), "Contract should not be paused initially");
        assertEq(bridge.nonce(), 0, "Nonce should start at 0");
    }

    // ============ ТЕСТЫ MINT FUNCTION ============

    function test_Mint_Success() public {
        // Arrange
        uint256 mintAmount = 100 ether;
        uint256 nonce = 1;

        // Act
        vm.prank(relayer);
        vm.expectEmit(true, true, true, true);
        emit Minted(user1, mintAmount, nonce, block.timestamp);
        bridge.mint(user1, mintAmount, nonce);

        // Assert
        assertEq(bridge.balances(user1), mintAmount, "Balance should be updated");
        assertEq(bridge.balanceOf(user1), mintAmount, "BalanceOf should return correct value");
        assertTrue(bridge.processedMints(nonce), "Nonce should be marked as processed");
    }

    function test_Mint_MultipleTimes() public {
        // Arrange
        uint256 mintAmount1 = 100 ether;
        uint256 mintAmount2 = 50 ether;
        uint256 nonce1 = 1;
        uint256 nonce2 = 2;

        // Act - первый mint
        vm.prank(relayer);
        bridge.mint(user1, mintAmount1, nonce1);

        // Assert после первого
        assertEq(bridge.balances(user1), mintAmount1, "Balance after first mint");

        // Act - второй mint
        vm.prank(relayer);
        bridge.mint(user1, mintAmount2, nonce2);

        // Assert после второго
        assertEq(bridge.balances(user1), mintAmount1 + mintAmount2, "Balance after second mint");
        assertTrue(bridge.processedMints(nonce1), "Nonce1 should be processed");
        assertTrue(bridge.processedMints(nonce2), "Nonce2 should be processed");
    }

    function test_Mint_ToDifferentUsers() public {
        // Arrange
        uint256 mintAmount1 = 100 ether;
        uint256 mintAmount2 = 200 ether;
        uint256 nonce1 = 1;
        uint256 nonce2 = 2;

        // Act
        vm.startPrank(relayer);
        bridge.mint(user1, mintAmount1, nonce1);
        bridge.mint(user2, mintAmount2, nonce2);
        vm.stopPrank();

        // Assert
        assertEq(bridge.balances(user1), mintAmount1, "User1 balance");
        assertEq(bridge.balances(user2), mintAmount2, "User2 balance");
    }

    function test_Mint_ZeroAmount() public {
        // Act & Assert
        vm.prank(relayer);
        vm.expectRevert(L2Bridge.ZeroAmount.selector);
        bridge.mint(user1, 0, 1);
    }

    function test_Mint_NotRelayer() public {
        // Act & Assert
        vm.prank(user1);
        vm.expectRevert(L2Bridge.Unauthorized.selector);
        bridge.mint(user1, 100 ether, 1);
    }

    function test_Mint_AttackerAsRelayer() public {
        // Act & Assert
        vm.prank(attacker);
        vm.expectRevert(L2Bridge.Unauthorized.selector);
        bridge.mint(user1, 100 ether, 1);
    }

    function test_Mint_DuplicateNonce() public {
        // Arrange
        uint256 mintAmount = 100 ether;
        uint256 nonce = 1;

        vm.prank(relayer);
        bridge.mint(user1, mintAmount, nonce);

        // Act & Assert - попытка использовать тот же nonce
        vm.prank(relayer);
        vm.expectRevert(L2Bridge.AlreadyProcessedMint.selector);
        bridge.mint(user1, mintAmount, nonce);
    }

    function test_Mint_WhenPaused() public {
        // Arrange - паузим контракт
        vm.prank(owner);
        bridge.changeContractPause();

        // Act & Assert
        vm.prank(relayer);
        vm.expectRevert(L2Bridge.ContractPaused.selector);
        bridge.mint(user1, 100 ether, 1);
    }

    function test_Mint_WithLargeNonce() public {
        // Arrange
        uint256 largeNonce = type(uint256).max;

        // Act
        vm.prank(relayer);
        bridge.mint(user1, 100 ether, largeNonce);

        // Assert
        assertTrue(bridge.processedMints(largeNonce), "Large nonce should work");
    }

    // ============ ТЕСТЫ BURN FUNCTION ============

    function test_Burn_Success() public {
        // Arrange - сначала mint
        uint256 mintAmount = 100 ether;
        uint256 burnAmount = 40 ether;
        uint256 mintNonce = 1;

        vm.prank(relayer);
        bridge.mint(user1, mintAmount, mintNonce);

        uint256 balanceBefore = bridge.balances(user1);
        uint256 nonceBefore = bridge.nonce();

        // Act - burn
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit Burned(user1, burnAmount, nonceBefore, block.timestamp);
        bridge.burn(burnAmount);

        // Assert
        assertEq(bridge.balances(user1), mintAmount - burnAmount, "Balance should decrease");
        assertEq(bridge.nonce(), nonceBefore + 1, "Nonce should increment");
    }

    function test_Burn_AllBalance() public {
        // Arrange - сначала mint
        uint256 mintAmount = 100 ether;
        uint256 mintNonce = 1;

        vm.prank(relayer);
        bridge.mint(user1, mintAmount, mintNonce);

        // Act - сжигаем все
        vm.prank(user1);
        bridge.burn(mintAmount);

        // Assert
        assertEq(bridge.balances(user1), 0, "Balance should be zero");
    }

    function test_Burn_ZeroAmount() public {
        // Act & Assert
        vm.prank(user1);
        vm.expectRevert(L2Bridge.ZeroAmount.selector);
        bridge.burn(0);
    }

    function test_Burn_InsufficientBalance() public {
        // Arrange - немного mint
        uint256 mintAmount = 10 ether;
        uint256 mintNonce = 1;

        vm.prank(relayer);
        bridge.mint(user1, mintAmount, mintNonce);

        // Act & Assert - пытаемся сжечь больше чем есть
        vm.prank(user1);
        vm.expectRevert(L2Bridge.InsufficientBalance.selector);
        bridge.burn(20 ether);
    }

    function test_Burn_NoBalance() public {
        // Act & Assert - пользователь без баланса
        vm.prank(user1);
        vm.expectRevert(L2Bridge.InsufficientBalance.selector);
        bridge.burn(1 ether);
    }

    function test_Burn_WhenPaused() public {
        // Arrange - mint и пауза
        vm.prank(relayer);
        bridge.mint(user1, 100 ether, 1);

        vm.prank(owner);
        bridge.changeContractPause();

        // Act & Assert
        vm.prank(user1);
        vm.expectRevert(L2Bridge.ContractPaused.selector);
        bridge.burn(50 ether);
    }

    // ============ ТЕСТЫ НА ВЗАИМОДЕЙСТВИЕ MINT + BURN ============

    function test_MultipleUsers_MintAndBurn() public {
        // Arrange & Act - mint для обоих пользователей
        vm.startPrank(relayer);
        bridge.mint(user1, 100 ether, 1);
        bridge.mint(user2, 200 ether, 2);
        vm.stopPrank();

        // Проверка начальных балансов
        assertEq(bridge.balanceOf(user1), 100 ether);
        assertEq(bridge.balanceOf(user2), 200 ether);

        // User1 сжигает
        vm.prank(user1);
        bridge.burn(30 ether);

        // User2 сжигает
        vm.prank(user2);
        bridge.burn(50 ether);

        // Финальные балансы
        assertEq(bridge.balanceOf(user1), 70 ether, "User1 final balance");
        assertEq(bridge.balanceOf(user2), 150 ether, "User2 final balance");
    }

    // ============ ТЕСТЫ НА PAUSE FUNCTIONALITY ============

    function test_Pause_ByOwner() public {
        // Act
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit Paused();
        bridge.changeContractPause();

        // Assert
        assertTrue(bridge.paused(), "Contract should be paused");
    }

    function test_Unpause_ByOwner() public {
        // Arrange
        vm.prank(owner);
        bridge.changeContractPause();
        assertTrue(bridge.paused());

        // Act
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit Unpaused();
        bridge.changeContractPause();

        // Assert
        assertFalse(bridge.paused(), "Contract should be unpaused");
    }

    function test_Pause_NotOwner() public {
        // Act & Assert
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        bridge.changeContractPause();
    }

    function test_Pause_MultipleToggles() public {
        vm.startPrank(owner);

        assertFalse(bridge.paused());

        bridge.changeContractPause();
        assertTrue(bridge.paused());

        bridge.changeContractPause();
        assertFalse(bridge.paused());

        bridge.changeContractPause();
        assertTrue(bridge.paused());

        vm.stopPrank();
    }

    // ============ ТЕСТЫ НА SET RELAYER ============

    function test_SetRelayer_ByOwner() public {
        // Arrange
        address newRelayer = makeAddr("newRelayer");

        // Act
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit RelayerSet(newRelayer);
        bridge.setRelayer(newRelayer);

        // Assert
        assertEq(bridge.relayer(), newRelayer, "Relayer should be updated");
    }

    function test_SetRelayer_NotOwner() public {
        // Act & Assert
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        bridge.setRelayer(attacker);
    }

    function test_SetRelayer_SameAddress() public {
        // Act
        vm.prank(owner);
        bridge.setRelayer(relayer);

        // Assert - ничего не изменилось
        assertEq(bridge.relayer(), relayer);
    }

    // ============ ТЕСТЫ НА ГРАНИЧНЫЕ УСЛОВИЯ ============

    function test_Mint_MaxUint256() public {
        // Arrange
        uint256 maxAmount = type(uint256).max;
        uint256 nonce = 1;

        // Act
        vm.prank(relayer);
        bridge.mint(user1, maxAmount, nonce);

        // Assert
        assertEq(bridge.balances(user1), maxAmount, "Should handle max uint");
    }

    function test_Burn_AfterMultipleMints() public {
        // Arrange - несколько mint
        vm.startPrank(relayer);
        bridge.mint(user1, 10 ether, 1);
        bridge.mint(user1, 20 ether, 2);
        bridge.mint(user1, 30 ether, 3);
        vm.stopPrank();

        assertEq(bridge.balanceOf(user1), 60 ether);

        // Act - сжигаем частями
        vm.startPrank(user1);
        bridge.burn(5 ether);
        bridge.burn(15 ether);
        bridge.burn(25 ether);
        vm.stopPrank();

        // Assert
        assertEq(bridge.balanceOf(user1), 15 ether, "60 - 45 = 15");
    }

    // ============ ТЕСТЫ НА ИВЕНТЫ ============

    function test_Mint_EventEmission() public {
        // Проверяем что ивент Minted эмитится с правильными параметрами
        uint256 amount = 100 ether;
        uint256 nonce = 42;

        vm.prank(relayer);
        vm.expectEmit(true, true, true, true);
        emit Minted(user1, amount, nonce, block.timestamp);
        bridge.mint(user1, amount, nonce);
    }

    function test_Burn_EventEmission() public {
        // Arrange
        vm.prank(relayer);
        bridge.mint(user1, 100 ether, 1);

        uint256 burnAmount = 30 ether;
        uint256 expectedNonce = bridge.nonce(); // должен быть 1

        // Act & Assert
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit Burned(user1, burnAmount, expectedNonce, block.timestamp);
        bridge.burn(burnAmount);
    }

    // ============ ТЕСТЫ НА ГАЗ ============

    function test_Mint_GasUsage() public {
        // Arrange
        uint256 amount = 100 ether;
        uint256 nonce = 1;

        vm.prank(relayer);

        // Act - измеряем газ
        uint256 gasBefore = gasleft();
        bridge.mint(user1, amount, nonce);
        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;

        // Assert - просто логируем
        console.log("Gas used for mint:", gasUsed);
        assertLt(gasUsed, 100000, "Mint should be gas efficient");
    }

    function test_Burn_GasUsage() public {
        // Arrange
        vm.prank(relayer);
        bridge.mint(user1, 100 ether, 1);

        vm.prank(user1);

        // Act - измеряем газ
        uint256 gasBefore = gasleft();
        bridge.burn(50 ether);
        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;

        // Assert
        console.log("Gas used for burn:", gasUsed);
        assertLt(gasUsed, 100000, "Burn should be gas efficient");
    }

    // ============ FUZZ ТЕСТЫ (RANDOMIZED) ============

    function testFuzz_MultipleMints(uint256 amount1, uint256 amount2, uint256 amount3) public {
        // Ограничиваем значения
        amount1 = bound(amount1, 1 ether, 100 ether);
        amount2 = bound(amount2, 1 ether, 100 ether);
        amount3 = bound(amount3, 1 ether, 100 ether);

        vm.startPrank(relayer);
        bridge.mint(user1, amount1, 1);
        bridge.mint(user1, amount2, 2);
        bridge.mint(user1, amount3, 3);
        vm.stopPrank();

        assertEq(bridge.balanceOf(user1), amount1 + amount2 + amount3, "Sum of mints should equal balance");
    }
}
