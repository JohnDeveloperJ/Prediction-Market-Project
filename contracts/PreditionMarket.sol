// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract PredictionMarket is VRFConsumerBase {
    address public owner;
    string public marketQuestion;
    uint256 public totalFunds;
    uint256 public outcome;
    bool public isMarketClosed;
    IERC20 public token; // ERC20 token for trading
    bytes32 public requestId;
    
    struct Participant {
        bool participated;
        uint256 prediction;
        uint256 tokensStaked;
    }
    
    mapping(address => Participant) public participants;
    
    event MarketCreated(string question);
    event ParticipantJoined(address participant, uint256 prediction, uint256 tokensStaked);
    event MarketClosed(uint256 winningOutcome);
    event WinningsClaimed(address participant, uint256 winnings);
    event RandomnessGenerated(bytes32 requestId, uint256 randomness);

    constructor(string memory _question, address _tokenAddress, address _vrfCoordinator, address _linkToken, bytes32 _keyHash) 
        VRFConsumerBase(_vrfCoordinator, _linkToken) {
        owner = msg.sender;
        marketQuestion = _question;
        isMarketClosed = false;
        token = IERC20(_tokenAddress);
        emit MarketCreated(_question);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }
    
    modifier isOpen() {
        require(!isMarketClosed, "The market is closed");
        _;
    }
    
    function joinMarket(uint256 _prediction, uint256 _tokensStaked) public isOpen {
        require(!participants[msg.sender].participated, "You have already participated");
        
        participants[msg.sender] = Participant(true, _prediction, _tokensStaked);
        totalFunds += _tokensStaked;
        token.transferFrom(msg.sender, address(this), _tokensStaked); // Transfer tokens to the contract
        
        emit ParticipantJoined(msg.sender, _prediction, _tokensStaked);
    }
    
    function closeMarket() public onlyOwner isOpen {
        // Generate random number using Chainlink VRF
        requestId = requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 _requestId, uint256 _randomness) internal override {
        require(msg.sender == vrfCoordinator, "Only the VRF coordinator can fulfill");
        require(_requestId == requestId, "Wrong request ID");

        outcome = _randomness % 2; // Example: Generate a random binary outcome (0 or 1)
        isMarketClosed = true;
        
        emit MarketClosed(outcome);
        emit RandomnessGenerated(_requestId, _randomness);
    }

    function claimWinnings() public {
        require(isMarketClosed, "The market is still open");
        
        Participant storage participant = participants[msg.sender];
        
        if (participant.prediction == outcome) {
            uint256 winnings = (participant.tokensStaked * totalFunds) / token.totalSupply();
            token.transfer(msg.sender, winnings);
            emit WinningsClaimed(msg.sender, winnings);
        }
        
        participant.participated = false; // Prevent multiple claims
    }
}
