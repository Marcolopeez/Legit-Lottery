//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol"; 
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title Raffle
 * @dev The Raffle contract is a simple contract for a raffle
 */
contract Raffle is VRFConsumerBaseV2 {
    enum RaffleState {OPEN, CALCULATING_WINNER} 

    // Chainlinnk VRF variables
    uint16 private constant _REQUEST_CONFIRMATIONS = 3;
    uint32 private constant _NUM_WORDS = 1;
    VRFCoordinatorV2Interface private immutable _vrfCoordinator;
    bytes32 private immutable _gasLane;
    uint64 private immutable _subscriptionId;
    uint32 private immutable _callbackGasLimit;

    // Raffle variables
    uint256 private immutable _entranceFee;
    // @dev duration of the lottery in seconds
    uint256 private immutable _interval;
    address payable[] private _players;
    uint256 private _lastTimestamp;
    address private _recentWinner;
    RaffleState private _raffleState; // Open by default

    error Raffle__NotEnoughEther();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__NotEnoughTimeElapsed();
    error Raffle__NotEnoughPlayers();

    event RaffleEnter(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);


    constructor(
        uint256 entranceFee, 
        uint256 interval, 
        address vrfCoordinator, 
        bytes32 gasLane, 
        uint64 subscriptionId, 
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator){
        _entranceFee = entranceFee;
        _interval = interval;
        _vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        _gasLane = gasLane;
        _subscriptionId = subscriptionId;
        _callbackGasLimit = callbackGasLimit;

        _lastTimestamp = block.timestamp;
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(msg.sender).transfer(balance);
        }
    }

    function enterRaffle() external payable {
        if(msg.value < _entranceFee){   
            revert Raffle__NotEnoughEther();
        }
        if(_raffleState != RaffleState.OPEN){
            revert Raffle__RaffleNotOpen();
        }
        _players.push(payable(msg.sender));
        // Emit an event when we update a dynamic array or mapping
        // Named events with the function name reversed
        emit RaffleEnter(msg.sender);
    }

    function pickWinner() public {
        if((block.timestamp - _lastTimestamp)  <= _interval){   
            revert Raffle__NotEnoughTimeElapsed();
        }
        if(_players.length == 0){
            revert Raffle__NotEnoughPlayers();
        }
        if(_raffleState != RaffleState.OPEN){
            revert Raffle__RaffleNotOpen();
        }
        
        _raffleState = RaffleState.CALCULATING_WINNER;
        uint256 requestId = _vrfCoordinator.requestRandomWords(
            _gasLane, 
            _subscriptionId,
            _REQUEST_CONFIRMATIONS,
            _callbackGasLimit,
            _NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }

    function getRaffleState() public view returns (RaffleState) {
        return _raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return _NUM_WORDS;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return _REQUEST_CONFIRMATIONS;
    }

    function getRecentWinner() public view returns (address) {
        return _recentWinner;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return _players[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return _lastTimestamp;
    }

    function getInterval() public view returns (uint256) {
        return _interval;
    }

    function getEntranceFee() public view returns (uint256) {
        return _entranceFee;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return _players.length;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 index = randomWords[0] % _players.length;
        address payable winner = _players[index];
        _recentWinner = winner;
        _players = new address payable[](0);
        _lastTimestamp = block.timestamp;
        _raffleState = RaffleState.OPEN;
        emit PickedWinner(winner);

        (bool success, ) = winner.call{value: address(this).balance}("");
        if(!success){
            revert Raffle__TransferFailed();
        }

    }


}