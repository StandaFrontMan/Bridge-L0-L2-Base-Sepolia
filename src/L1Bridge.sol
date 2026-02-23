// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract L1Bridge is Ownable, ReentrancyGuard {
    uint256 public constant DAILY_RATE_LIMIT = 100 ether;
    uint256 public minBridgeAmount = 0.001 ether;
    uint256 public maxBridgeLimit = 5 ether;
    uint256 public totalBridgedToday;
    uint256 public lastResetDay;
    uint256 public nonce;
    bool public paused;
    address public relayer;

    mapping(address => uint256) public usersDailyRateLimits;
    mapping(address => uint256) public usersLastBridgeDay;
    mapping(uint256 => bool) public processedWithdrawals;

    error ZeroAmount();
    error GlobalDailyRateLimitReached();
    error PersonalDailyRateLimitReached();
    error MaxBridgeTransactionLimitReached();
    error MinBridgeTransactionLimitReached();
    error MaxValuereached();
    error MinValuereached();
    error ContractPaused();
    error Unauthorized();
    error AlreadyProcessedWithdraw();
    error InsufficientBalanceForWithdraw();
    error TransferFailed();

    event Depositing(
        address indexed depositor, address indexed recipient, uint256 indexed nonce, uint256 amount, uint256 timestamp
    );
    event Paused();
    event Unpaused();
    event RelayerSet(address indexed relayer);
    event Withdrawn(address indexed withdrawer, uint256 amount, uint256 indexed nonce, uint256 timestamp);

    /// @notice Enforces global and personal daily bridge limits.
    /// @param _address The address initiating the bridge.
    /// @param amount The amount of ETH being bridged.
    modifier rateLimit(address _address, uint256 amount) {
        _rateLimit(_address, amount);
        _;
    }

    /// @notice Validates that the bridge amount is within the allowed transaction limits
    /// @param _amount The amount of ETH being bridged in the current transaction
    modifier bridgeTxLimit(uint256 _amount) {
        _bridgeTxLimit(_amount);
        _;
    }

    /// @notice Ensures the contract is not paused before allowing bridge operations
    /// @custom:throws ContractPaused if the contract is currently in paused state
    modifier isContractPaused() {
        _isContractPaused();
        _;
    }

    constructor() Ownable(msg.sender) {}

    function bridge(address recipient)
        public
        payable
        nonReentrant
        isContractPaused
        bridgeTxLimit(msg.value)
        rateLimit(msg.sender, msg.value)
    {
        require(msg.value > 0, ZeroAmount());

        uint256 currentNonce = nonce++;

        /// @notice If the user wants to bridge to a different address,
        /// they must provide it explicitly.
        address targetRecipientAddr = recipient == address(0) ? msg.sender : recipient;

        emit Depositing(msg.sender, targetRecipientAddr, currentNonce, msg.value, block.timestamp);
    }

    function withdraw(address user, uint256 amount, uint256 _nonce) external nonReentrant isContractPaused {
        require(msg.sender == relayer, Unauthorized());
        if (processedWithdrawals[_nonce] == true) revert AlreadyProcessedWithdraw();
        require(address(this).balance >= amount, InsufficientBalanceForWithdraw());

        processedWithdrawals[_nonce] = true;

        (bool success,) = payable(user).call{value: amount}("");
        require(success, TransferFailed());

        emit Withdrawn(user, amount, _nonce, block.timestamp);
    }

    receive() external payable {
        bridge(msg.sender);
    }

    fallback() external payable {
        bridge(msg.sender);
    }

    function _rateLimit(address _address, uint256 amount) internal {
        uint256 today = block.timestamp / 1 days;

        if (today > lastResetDay) {
            totalBridgedToday = 0;
            lastResetDay = today;
        }

        if (totalBridgedToday + amount > DAILY_RATE_LIMIT) {
            revert GlobalDailyRateLimitReached();
        }

        if (today > usersLastBridgeDay[_address]) {
            usersDailyRateLimits[_address] = 0;
            usersLastBridgeDay[_address] = today;
        }

        if (usersDailyRateLimits[_address] + amount > DAILY_RATE_LIMIT / 10) {
            revert PersonalDailyRateLimitReached();
        }

        totalBridgedToday += amount;
        usersDailyRateLimits[_address] += amount;
    }

    function _bridgeTxLimit(uint256 _amount) internal view {
        require(_amount <= maxBridgeLimit, MaxBridgeTransactionLimitReached());
        require(_amount >= minBridgeAmount, MinBridgeTransactionLimitReached());
    }

    function setMaxBridgeTransactionLimit(uint256 _maxLimit) external onlyOwner {
        require(_maxLimit <= DAILY_RATE_LIMIT / 10, MaxValuereached());
        maxBridgeLimit = _maxLimit;
    }

    function setMinBridgeTransactionLimit(uint256 _minLimit) external onlyOwner {
        require(_minLimit <= maxBridgeLimit, MinValuereached());
        minBridgeAmount = _minLimit;
    }

    function _isContractPaused() internal view {
        if (paused) revert ContractPaused();
    }

    function changeContractPause() external onlyOwner {
        paused = !paused;
        if (paused) {
            emit Paused();
        } else {
            emit Unpaused();
        }
    }

    function setRelayer(address _relayer) external onlyOwner {
        relayer = _relayer;
        emit RelayerSet(_relayer);
    }
}
