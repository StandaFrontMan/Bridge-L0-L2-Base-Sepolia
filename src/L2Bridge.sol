// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract L2Bridge is Ownable, ReentrancyGuard {
    address public relayer;

    bool public paused; 

    error Unauthorized();
    error ContractPaused();

    event RelayerSet(address indexed relayer);
    event Paused();
    event Unpaused();

    /// @notice Ensures the contract is not paused before allowing bridge operations
    /// @custom:throws ContractPaused if the contract is currently in paused state
    modifier isContractPaused() {
        _isContractPaused();
        _;
    }

    constructor () Ownable(msg.sender) {}

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