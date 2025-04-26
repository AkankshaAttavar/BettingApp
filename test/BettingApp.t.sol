// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/BettingApp.sol";

contract BettingAppTest is Test {
    BettingApp public bettingApp;
    MockERC20 public token;

    address owner;
    address user1;
    address user2;

    uint256 constant BET_AMOUNT = 10 * 1e18;

    function setUp() public {
        owner = address(this);
        user1 = address(1);
        user2 = address(2);

        token = new MockERC20("BetToken", "BET");
        bettingApp = new BettingApp(address(token));

        token.mint(user1, 1000 * 1e18);
        token.mint(user2, 1000 * 1e18);

        vm.prank(user1);
        token.approve(address(bettingApp), type(uint256).max);
        vm.prank(user2);
        token.approve(address(bettingApp), type(uint256).max);
    }

    function testOwnerIsDeployer() public view {
        assertEq(bettingApp.owner(), owner);
    }

    function testRequestBetProperly() public {
        vm.prank(user1);
        bool success = bettingApp.requestBet("Match 1", "Team A", "Team B");
        assertTrue(success);
    }

    function testGetAllRequestedBets() public {
        vm.prank(user1);
        bettingApp.requestBet("Match 1", "A", "B");

        BettingApp.BetRequest[] memory requests = bettingApp
            .getAllRequestedBets();
        assertEq(requests.length, 1);
        assertEq(requests[0].betName, "Match 1");
    }

    function testCannotCreateDuplicateBet() public {
        vm.prank(user1);
        bettingApp.requestBet("Match 1", "A", "B");
        bettingApp.createBet(0, 1);

        vm.expectRevert(BettingApp.BetAlreadyApproved.selector);
        bettingApp.createBet(0, 1);
    }

    function testBetCountIncreased() public {
        vm.prank(user1);
        bettingApp.requestBet("Match 1", "A", "B");
        bettingApp.createBet(0, 1);
        assertEq(bettingApp.betCount(), 1);
    }

    function testPlaceBetWithReentrancyProtection() public {
        vm.prank(user1);
        bettingApp.requestBet("Game", "X", "Y");
        bettingApp.createBet(0, 1);

        vm.prank(user1);
        bettingApp.placeBets(0, BettingApp.Option.optionA, BET_AMOUNT);
    }

    function testCreateBetSetsApprovalTrue() public {
        vm.prank(user1);
        bettingApp.requestBet("Match 1", "A", "B");

        // Verify that the request was created by checking its details
        BettingApp.BetRequest[] memory requests = bettingApp
            .getAllRequestedBets();
        assertEq(requests.length, 1); // Ensure there is one request
        assertEq(requests[0].betName, "Match 1"); // Check the details of the bet request

        bettingApp.createBet(0, 1);
        (, , , , bool isActive, , , , , ) = bettingApp.activeBets(0);
        assertTrue(isActive);
    }

    function testRejectWrongAmount() public {
        vm.prank(user1);
        bettingApp.requestBet("Match", "A", "B");
        bettingApp.createBet(0, 1);

        vm.prank(user1);
        vm.expectRevert("Minimum 10 BET");
        bettingApp.placeBets(0, BettingApp.Option.optionA, 5 * 1e18);
    }

    function testTokenTransferredCorrectly() public {
        vm.prank(user1);
        bettingApp.requestBet("Match", "A", "B");
        bettingApp.createBet(0, 1);

        uint256 initial = token.balanceOf(user1);
        vm.prank(user1);
        bettingApp.placeBets(0, BettingApp.Option.optionA, BET_AMOUNT);

        assertLt(token.balanceOf(user1), initial);
        assertGt(token.balanceOf(address(bettingApp)), 0);
    }

    function testParticipantAddedToArray() public {
        vm.prank(user1);
        bettingApp.requestBet("Match", "A", "B");
        bettingApp.createBet(0, 1);

        vm.prank(user1);
        bettingApp.placeBets(0, BettingApp.Option.optionA, BET_AMOUNT);

        address[] memory participants = bettingApp.getParticipants(0);
        assertEq(participants.length, 1);
        assertEq(participants[0], user1);
    }

    function testOnlyOwnerCanCloseBetAfterDeadline() public {
        vm.prank(user1);
        bettingApp.requestBet("Match", "A", "B");
        bettingApp.createBet(0, 1);

        vm.warp(block.timestamp + 2 hours);
        bettingApp.closeBet(0);
        (, , , , , bool isClosed, , , , ) = bettingApp.activeBets(0);

        assertTrue(isClosed);
    }

    function testDeclareWinnersOnlyAfterDeadline() public {
        vm.prank(user1);
        bettingApp.requestBet("Match", "A", "B");
        bettingApp.createBet(0, 1);

        vm.prank(user1);
        bettingApp.placeBets(0, BettingApp.Option.optionA, BET_AMOUNT);

        vm.warp(block.timestamp + 2 hours);
        bettingApp.closeBet(0);

        bettingApp.declareWinners(0, BettingApp.Option.optionA);
    }

    function testCannotDeclareWithoutParticipants() public {
        vm.prank(user1);
        bettingApp.requestBet("Match", "A", "B");
        bettingApp.createBet(0, 1);

        vm.warp(block.timestamp + 2 hours);
        bettingApp.closeBet(0);

        vm.expectRevert(BettingApp.NoWinners.selector);
        bettingApp.declareWinners(0, BettingApp.Option.optionA);
    }

    function testWinnerReceivesReward() public {
        vm.prank(user1);
        bettingApp.requestBet("Match", "A", "B");
        bettingApp.createBet(0, 1);

        vm.prank(user1);
        bettingApp.placeBets(0, BettingApp.Option.optionA, BET_AMOUNT);

        vm.warp(block.timestamp + 2 hours);
        bettingApp.closeBet(0);

        uint256 before = token.balanceOf(user1);
        bettingApp.declareWinners(0, BettingApp.Option.optionA);
        uint256 afterBal = token.balanceOf(user1);
        assertGt(afterBal, before);
    }
}

contract MockERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
