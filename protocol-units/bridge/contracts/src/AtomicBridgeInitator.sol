// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IAtomicBridgeInitiator} from "./IAtomicBridgeInitiator.sol";
import {IWETH9} from "./IWETH9.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract AtomicBridgeInitiator is IAtomicBridgeInitiator, AccessControlUpgradeable {
    struct BridgeTransfer {
        uint256 amount;
        address originator;
        bytes32 recipient;
        bytes32 hashLock;
        uint256 timeLock;
        bool completed;
    }

    mapping(bytes32 => BridgeTransfer) public bridgeTransfers;
    bytes32[] public bridgeTransferIds;
    // keccak256(abi.encode(uint256(keccak256("Bridge"")))
    bytes32 public BRIDGE_ROLE = 0x7149ba3a956df41b15775a58d31c6519ac4174ae65ab86e40583abd483069022;
    IWETH9 public weth;
    uint256 private nonce;

    modifier onlyBridgeService() {
        if (!_checkRole(BRIDGE_ROLE)) revert Unauthorized();
    }

    function initialize(address _weth) public initializer {
        if (_weth == address(0)) {
            revert ZeroAddress();
        }
        _grantRole(BRIDGE_ROLE, msg.sender);
        weth = IWETH9(_weth);
    }

    function initiateBridgeTransfer(uint256 wethAmount, bytes32 recipient, bytes32 hashLock, uint256 timeLock)
        external
        payable
        returns (bytes32 bridgeTransferId)
    {
        address originator = msg.sender;
        uint256 ethAmount = msg.value;
        uint256 totalAmount = wethAmount + ethAmount;
        // Ensure there is a valid total amount
        if (totalAmount == 0) {
            revert ZeroAmount();
        }
        // If msg.value is greater than 0, convert ETH to WETH
        if (ethAmount > 0) weth.deposit{value: ethAmount}();
        //Transfer WETH to this contract, revert if transfer fails
        if (wethAmount > 0) {
            if (!weth.transferFrom(originator, address(this), wethAmount)) revert WETHTransferFailed();
        }

        nonce++; //increment the nonce
        bridgeTransferId =
            keccak256(abi.encodePacked(originator, recipient, hashLock, timeLock, block.timestamp, nonce));

        // Check if the bridge transfer already exists
        if (bridgeTransfers[bridgeTransferId].amount != 0) revert BridgeTransferInvalid();

        bridgeTransfers[bridgeTransferId] = BridgeTransfer({
            amount: totalAmount,
            originator: originator,
            recipient: recipient,
            hashLock: hashLock,
            timeLock: block.timestamp + timeLock,
            completed: false
        });

        bridgeTransferIds.push(bridgeTransferId);

        emit BridgeTransferInitiated(bridgeTransferId, originator, recipient, totalAmount, hashLock, timeLock);
        return bridgeTransferId;
    }

    function completeBridgeTransfer(bytes32 bridgeTransferId, bytes32 preImage) external {
        // Retrieve the bridge transfer
        BridgeTransfer storage bridgeTransfer = bridgeTransfers[bridgeTransferId];
        uint256 amount = bridgeTransfer.amount;
        if (bridgeTransfer.completed) revert BridgeTransferHasBeenCompleted();
        if (keccak256(abi.encodePacked(preImage)) != bridgeTransfer.hashLock) revert InvalidSecret();

        // WETH remains stored in the contract
        // Only to be released upon bridge transfer in the opposite  wdirection

        bridgeTransfer.completed = true;
        emit BridgeTransferCompleted(bridgeTransferId, preImage);
    }

    function refundBridgeTransfer(bytes32 bridgeTransferId) external {
        BridgeTransfer storage bridgeTransfer = bridgeTransfers[bridgeTransferId];
        uint256 amount = bridgeTransfer.amount;
        if (bridgeTransfer.completed) revert BridgeTransferHasBeenCompleted();
        if (block.timestamp < bridgeTransfer.timeLock) revert TimeLockNotExpired();

        bridgeTransfer.completed = true;

        if (!weth.transfer(bridgeTransfer.originator, amount)) revert WETHTransferFailed();
        emit BridgeTransferRefunded(bridgeTransferId);
    }

    // Get all bridge transfer ids, the solidity get method only returns one item by index
    function getAllBridgeTransferIds() external view returns (bytes32[] memory) {
        return bridgeTransferIds;
    }
}
