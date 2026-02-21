// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract L1Bridge is Ownable, ReentrancyGuard {
    uint256 public nonce;

    error ZeroAmount();

    event Depositing(
        address indexed depositor, address indexed recipient, uint256 indexed nonce, uint256 amount, uint256 timestamp
    );

    constructor() Ownable(msg.sender) {}

    function bridge(address recipient) public payable nonReentrant {
        require(msg.value > 0, ZeroAmount());

        uint256 currentNonce = nonce++;

        /// @notice If the user wants to bridge to a different address,
        /// they must provide it explicitly.
        address targetRecipientAddr = recipient == address(0) ? msg.sender : recipient;

        emit Depositing(msg.sender, targetRecipientAddr, currentNonce, msg.value, block.timestamp);
    }

    receive() external payable {
        bridge(msg.sender);
    }

    fallback() external payable {
        bridge(msg.sender);
    }
}
