// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract L2Bridge is Ownable, ReentrancyGuard {
    address public relayer;
    bool public paused; 
    uint256 public nonce;

    mapping(uint256 => bool) public processedMints;
    mapping(address => uint256) public balances;

    error Unauthorized();
    error ContractPaused();
    error AlreadyProcessedMint();
    error ZeroAmount();
    error InsufficientBalance();

    event RelayerSet(address indexed relayer);
    event Paused();
    event Unpaused();
    event Minted(address indexed minter, uint256 amount, uint256 indexed nonce, uint256 timestamp);
    event Burned(
        address indexed user,
        uint256 amount,
        uint256 indexed nonce,
        uint256 timestamp
    );

    /// @notice Ensures the contract is not paused before allowing bridge operations
    /// @custom:throws ContractPaused if the contract is currently in paused state
    modifier isContractPaused() {
        _isContractPaused();
        _;
    }

    constructor () Ownable(msg.sender) {}

    function mint(address user, uint256 amount, uint256 _nonce) external nonReentrant isContractPaused {
        if (msg.sender != relayer) revert Unauthorized();
        if (processedMints[_nonce] == true) revert AlreadyProcessedMint();
        if (amount == 0) revert ZeroAmount();

        processedMints[_nonce] = true;
        balances[user] += amount;

        emit Minted(user, amount, _nonce, block.timestamp);
    }

    function burn(uint256 amount) external nonReentrant isContractPaused {
        if (amount == 0) revert ZeroAmount();
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        balances[msg.sender] -= amount;
        uint256 currentNonce = nonce++;

        emit Burned(msg.sender, amount, currentNonce, block.timestamp);
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

    function balanceOf(address user) external view returns(uint256) {
        return balances[user];
    }
}