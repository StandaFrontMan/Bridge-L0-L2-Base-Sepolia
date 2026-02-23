// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract L2Bridge is Ownable, ReentrancyGuard {
    address public relayer;

    error Unauthorized();

    event RelayerSet(address indexed relayer);

    constructor () Ownable(msg.sender) {}

    function setRelayer(address _relayer) external onlyOwner {
        relayer = _relayer;
        emit RelayerSet(_relayer);
    }
}