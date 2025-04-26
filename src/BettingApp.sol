// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract BettingApp is ReentrancyGuard {
    address public owner;
    uint256 public betCount;
    IERC20 public betToken;
    uint256 public bettingFeePercent = 2;

    // Enums
    enum Option {
        optionA,
        optionB
    }

    // Structs
    struct BetRequest {
        address user;
        string betName;
        string optionA;
        string optionB;
        bool Approved;
    }

    struct Bet {
        address user;
        string betName;
        string optionA;
        string optionB;
        bool isActive;
        bool isClosed;
        uint256 deadline;
        address[] participants;
        Option winner;
        uint256 totalPool;
        uint256 winnerCount;
    }

    mapping(uint256 => Bet) public activeBets;
    mapping(uint256 => mapping(address => Option)) public userBets;
    mapping(uint256 => mapping(address => bool)) public hasBet;
    BetRequest[] public betRequests;

    error OnlyOwner(address caller);
    error NotWinner();
    error InvalidBetId();
    error BetNotActive();
    error BetStillOpen();
    error BetAlreadyClosed();
    error AlreadyPlacedBet();
    error NoWinners();
    error BetAlreadyApproved();
    error BetDeadlinePassed();

    event BetRequested(address user, string optionA, string optionB);
    event BetCreated(uint256 betId, string betName);
    event BetPlaced(uint256 betId, address user, Option optionSelected);
    event BetClosed(uint256 betId);
    event WinnerPicked(uint256 betId, Option winningOption);
    event WinnerRecievedReward(
        uint256 betId,
        address participant,
        uint256 reward
    );
    event FeeCollected(address to, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner(msg.sender);
        _;
    }

    constructor(address _tokenAddress) {
        owner = msg.sender;
        betToken = IERC20(_tokenAddress);
    }

    function requestBet(
        string memory _betName,
        string memory _optionA,
        string memory _optionB
    ) public returns (bool) {
        betRequests.push(
            BetRequest({
                user: msg.sender,
                betName: _betName,
                optionA: _optionA,
                optionB: _optionB,
                Approved: false
            })
        );
        emit BetRequested(msg.sender, _optionA, _optionB);
        return true;
    }

    function getAllRequestedBets()
        public
        view
        onlyOwner
        returns (BetRequest[] memory)
    {
        return betRequests;
    }

    function createBet(
        uint256 requestIndex,
        uint256 durationInHours
    ) public onlyOwner {
        require(requestIndex < betRequests.length, "Invalid request index");

        BetRequest storage request = betRequests[requestIndex];
        if (request.Approved) revert BetAlreadyApproved();
        request.Approved = true;

        Bet storage newBet = activeBets[betCount];
        newBet.user = request.user;
        newBet.betName = request.betName;
        newBet.optionA = request.optionA;
        newBet.optionB = request.optionB;
        newBet.isActive = true;
        newBet.deadline = block.timestamp + (durationInHours * 1 hours);

        emit BetCreated(betCount, request.betName);
        betCount++;
    }

    function getBetAmount() public pure returns (uint256) {
        return 10 * 10 ** 18;
    }

    function placeBets(
        uint256 betId,
        Option selectedOption,
        uint256 amount
    ) public nonReentrant {
        Bet storage bet = activeBets[betId];
        if (bet.user == address(0)) revert InvalidBetId();

        if (!bet.isActive) revert BetNotActive();
        if (bet.isClosed) revert BetAlreadyClosed();
        if (block.timestamp >= bet.deadline) revert BetDeadlinePassed();
        if (hasBet[betId][msg.sender]) revert AlreadyPlacedBet();
        require(amount == 10 * 10 ** 18, "BET OF 10 Token is only valid");

        uint256 fee = (amount * bettingFeePercent) / 100;
        uint256 amountAfterFee = amount - fee;
        require(
            betToken.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );
        require(betToken.transfer(owner, fee), "Fee transfer failed");

        emit FeeCollected(owner, fee);

        userBets[betId][msg.sender] = selectedOption;
        hasBet[betId][msg.sender] = true;
        bet.participants.push(msg.sender);
        bet.totalPool += amountAfterFee;

        emit BetPlaced(betId, msg.sender, selectedOption);
    }

    function closeBet(uint256 betId) public onlyOwner {
        Bet storage bet = activeBets[betId];
        if (bet.user == address(0)) revert InvalidBetId();

        if (!bet.isActive) revert BetNotActive();
        if (bet.isClosed) revert BetAlreadyClosed();
        if (block.timestamp < bet.deadline) revert BetDeadlinePassed();

        bet.isActive = false;
        bet.isClosed = true;
        emit BetClosed(betId);
    }

    function declareWinners(
        uint256 betId,
        Option winningOption
    ) public onlyOwner {
        Bet storage bet = activeBets[betId];
        if (bet.user == address(0)) revert InvalidBetId();

        if (!bet.isClosed) revert BetStillOpen();

        bet.winner = winningOption;

        uint256 winners = 0;
        for (uint256 i = 0; i < bet.participants.length; i++) {
            if (userBets[betId][bet.participants[i]] == winningOption) {
                winners++;
            }
        }
        emit WinnerPicked(betId, winningOption);

        if (winners == 0) revert NoWinners();

        bet.winnerCount = winners;
        uint256 reward = bet.totalPool / winners;

        for (uint256 i = 0; i < bet.participants.length; i++) {
            address participant = bet.participants[i];
            if (userBets[betId][participant] == winningOption) {
                require(
                    betToken.transfer(participant, reward),
                    "Reward transfer failed"
                );
                emit WinnerRecievedReward(betId, participant, reward);
            }
        }
    }

    function getParticipants(
        uint256 betId
    ) public view returns (address[] memory) {
        require(betId < betCount, "Invalid Bet ID");
        return activeBets[betId].participants;
    }
}
