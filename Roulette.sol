//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./IERC20.sol";
import "./SafeMath.sol";
import "./Address.sol";
import "./IUniswapV2Router02.sol";
import "./ReentrantGuard.sol";

/**
 * 
 * FUN Proof Of Concept Roulette Game Via Smart Contract 
 * Made For Fun And To Prove It Is Possible
 * 
 */
contract Roulette is ReentrancyGuard {
    
    using SafeMath for uint256;
    using Address for address;
    
    // useless CA for default
    address constant _default = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    // house
    address private immutable house;
    // PCS router
    IUniswapV2Router02 immutable router;
    // salt
    uint256 private salt;
    // whether or not number is red or black
    mapping ( uint256 => bool) isRed;
    // 0 - 37 is valid | 37 is double zero
    uint256 constant validNumbers = 37;
    // 32x payout for numbers
    uint256 constant numberPayOut = 32;
    // 3x for thirds
    uint256 constant thirdsPayOut = 3;
    // 2x for red/blue and even/odd
    uint256 constant evenOddsPayOut = 2;
    // minimum bet
    uint256 minBet = 10**16;
    // maximum bet
    uint256 maxBet = 10**18;
    // only house can call
    modifier onlyHouse(){require(msg.sender == house, 'Only House'); _;}
    // player
    struct Player {
        uint256[] nums;
        uint256[] betVals;
        uint256 totalBet;
        uint256 totalAllocated;
        bool betOnEvens;
        uint256 amountBetOnEven;
        bool evens;
        bool betOnColor;
        uint256 amountBetOnColor;
        bool red;
        bool betOnThirds;
        uint256 amountBetOnThirds;
        uint256 whichThird;
        uint256 winnings;
    }
    
    // players prefered tokens
    mapping ( address => address) preferedToken;
    mapping ( address => bool) isApproved;
    mapping ( address => bool) isInjector;
    
    // participants in game
    mapping ( address => Player) participants;
    address[] players;

    // game stats
    uint256 gameStartTime;
    uint256 public gameDuration = 50;
    bool gameIsOn;
    
    // game is halted
    bool _gameHalted;
    
    // max players per game
    uint256 maxPlayersPerGame = 5;
    modifier gameNotEnded() {require(!gameCanBeEnded(), 'Time To End Game'); _;}
    
    // events
    event RouletteChosen(uint256 number);
    event Winner(address winner, uint256 amountBNB);
   
    constructor() {
        router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        house = msg.sender;
        isInjector[msg.sender] = true;
        isRed[1] = true;
        isRed[3] = true;
        isRed[5] = true;
        isRed[7] = true;
        isRed[9] = true;
        isRed[12] = true;
        isRed[14] = true;
        isRed[16] = true;
        isRed[18] = true;
        isRed[19] = true;
        isRed[21] = true;
        isRed[23] = true;
        isRed[25] = true;
        isRed[27] = true;
        isRed[30] = true;
        isRed[32] = true;
        isRed[34] = true;
        isRed[36] = true;
    }
    
    
    ////////////////////////////////////////
    /////////        HOUSE        //////////
    ////////////////////////////////////////
    
    function withdrawBNB(uint256 amount) external onlyHouse {
        require(!gameIsOn, 'Game In Progress');
        (bool succ,) = payable(msg.sender).call{value:amount}("");
        require(succ, 'Failure On BNB Withdrawal');
    }
    
    function withdrawTokens(address token) external onlyHouse {
        uint256 bal = IERC20(token).balanceOf(address(this));
        require(bal > 0, 'Insufficient Balance');
        IERC20(token).transfer(msg.sender, bal);
    }
    
    function haltGame(bool halt) external onlyHouse {
        _gameHalted = halt;
        if (halt) {
            gameIsOn = false;
        }
    }
    
    function setGameDuration(uint256 newDuration) external onlyHouse {
        gameDuration = newDuration;
    }
    
    function setMaxBet(uint256 newMaxBet) external onlyHouse {
        maxBet = newMaxBet;
    }
    
    function setMaxPlayersPerGame(uint256 playersPerGame) external onlyHouse {
        maxPlayersPerGame = playersPerGame;
    }
    
    function setApproved(address user, bool approved) external onlyHouse {
        isApproved[user] = approved;
    }
    
    function setInjector(address user, bool injector) external onlyHouse {
        isInjector[user] = injector;
    }
    
    function destroyGame() external onlyHouse {
        selfdestruct(payable(msg.sender));
    }
    
    function buyToken(address _token, address winner, uint256 bnb) internal {
        // ensure not default
        _token = _token == address(0) ? _default : _token;
        // balance before swap
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = _token;
        // swap for token, storing in winner
        router.swapExactETHForTokens{value: bnb}(
            0,
            path,
            winner,
            block.timestamp.add(30)
        );
    }
    
    ////////////////////////////////////////
    ////////         READ         //////////
    ////////////////////////////////////////

    function includes(address[] memory people, address player) public pure returns(bool){
        for (uint i =0 ; i < people.length; i++) {
            if (player == people[i]) return true;
        }
        return false;
    }
    
    function includesNum(uint256[] memory bets, uint256 num) public pure returns(bool){
        for (uint i =0 ; i < bets.length; i++) {
            if (num == bets[i]) return true;
        }
        return false;
    }
    
    function generateRoulleteNumber() internal view returns (uint256) {
        return ((salt*(block.timestamp**2 % block.number) + block.number) % (validNumbers+1));
    }
    
    function isEven(uint256 num) internal pure returns (bool) {
        return num % 2 == 0;
    }

    function IsRed(uint256 num) external view returns (bool) {
        return isRed[num];
    }
    
    function whichThird(uint256 num) internal pure returns (uint256) {
        if (num == 0 || num == 37) {
            return 27;
        }
        if (num <= 12) return 1;
        else if (num <= 24) return 2;
        else if (num <= 36) return 3;
        else return 27;
    }
    
    function gameCanBeEnded() public view returns (bool) {
        return gameStartTime + gameDuration <= block.number && gameIsOn;
    }
    
    function pointsLeftToAllocate(address user) public view returns (uint256) {
        return (participants[user].totalBet.sub(participants[user].totalAllocated)).div(minBet);
    }
    
    
    ////////////////////////////////////////
    ////////         BETS         //////////
    ////////////////////////////////////////
    
    function betThirds(uint256 whatThird, uint256 amount) external gameNotEnded {
        require(includes(players, msg.sender), 'Not In Game');
        require(!participants[msg.sender].betOnThirds, 'Already Bet On Thirds');
        require(whatThird > 0 && whatThird < 4, 'Incorrect Range');
        require(amount > 0, 'Zero Amount');
        
        participants[msg.sender].betOnThirds = true;
        participants[msg.sender].amountBetOnThirds += amount.mul(minBet);
        participants[msg.sender].whichThird = whatThird;
        // allocate
        allocate(msg.sender, amount.mul(minBet));
    }
    
    function betRed(uint256 amount) external gameNotEnded {
        require(includes(players, msg.sender), 'Not In Game');
        require(!participants[msg.sender].betOnColor, 'Already Bet On Evens');
        require(amount > 0, 'Zero Amount');
        
        participants[msg.sender].betOnColor = true;
        participants[msg.sender].amountBetOnColor += amount.mul(minBet);
        participants[msg.sender].red = true;
        // allocate
        allocate(msg.sender, amount.mul(minBet));
    }
    
    function betBlack(uint256 amount) external gameNotEnded{
        require(includes(players, msg.sender), 'Not In Game');
        require(!participants[msg.sender].betOnColor, 'Already Bet On Evens');
        require(amount > 0, 'Zero Amount');
        
        participants[msg.sender].betOnColor = true;
        participants[msg.sender].amountBetOnColor += amount.mul(minBet);
        participants[msg.sender].red = false;
        // allocate
        allocate(msg.sender, amount.mul(minBet));
    }
    
    function betEven(uint256 amount) external gameNotEnded {
        require(includes(players, msg.sender), 'Not In Game');
        require(!participants[msg.sender].betOnEvens, 'Already Bet On Evens');
        require(amount > 0, 'Zero Amount');
        
        participants[msg.sender].betOnEvens = true;
        participants[msg.sender].amountBetOnEven += amount.mul(minBet);
        participants[msg.sender].evens = true;
        // allocate
        allocate(msg.sender, amount.mul(minBet));
    }
    
    function betOdd(uint256 amount) external gameNotEnded {
        require(includes(players, msg.sender), 'Not In Game');
        require(!participants[msg.sender].betOnEvens, 'Already Bet On Evens');
        require(amount > 0, 'Zero Amount');
        
        participants[msg.sender].betOnEvens = true;
        participants[msg.sender].amountBetOnEven += amount.mul(minBet);
        participants[msg.sender].evens = false;
        // allocate
        allocate(msg.sender, amount.mul(minBet));
    }
    
    function bet(uint256 num, uint256 amount) external gameNotEnded {
        require(includes(players, msg.sender), 'Not In Game');
        require(!includesNum(participants[msg.sender].nums, num), 'Number Already Included');
        require(amount > 0, 'Zero Amount');
        // how much bnb is being allocated
        uint256 bnbAmount = amount.mul(minBet);
        // allocate bnb
        participants[msg.sender].nums.push(num);
        participants[msg.sender].betVals.push(bnbAmount);
        // add to allocation
        allocate(msg.sender, bnbAmount);
    }
    
    function batchBet(uint256[] calldata nums, uint256[] calldata amounts) external gameNotEnded {
        require(includes(players, msg.sender), 'Not In Game');
        require(nums.length == amounts.length, 'Invalid Input');
        
        uint256 totalBnbAmount;
        for (uint i = 0; i < nums.length; i++) {
            require(!includesNum(participants[msg.sender].nums, nums[i]), 'Number Already Included');
            require(amounts[i] > 0, 'Zero Amount');
            // increment total spent
            totalBnbAmount += amounts[i].mul(minBet);
            // allocate bnb
            participants[msg.sender].nums.push(nums[i]);
            participants[msg.sender].betVals.push(amounts[i].mul(minBet));
        }
        // add to allocation
        allocate(msg.sender, totalBnbAmount);
    }
    
    function setPayoutToken(address token) external {
        preferedToken[msg.sender] = token;
    }
    
    function allocate(address user, uint256 amount) private {
        participants[user].totalAllocated += amount;
        require(participants[user].totalAllocated <= participants[user].totalBet, 'Cannot Allocate More Than Bet');
    }

    
    
    ////////////////////////////////////////
    ////////         SPIN         //////////
    ////////////////////////////////////////
    
    
    
    function SpinWheel() external nonReentrant {
        require(includes(players, msg.sender) || msg.sender == house, 'Not In Game');
        require(gameCanBeEnded(), 'Not Time To End Game');
        // random number
        uint256 roll = generateRoulleteNumber();
        emit RouletteChosen(roll);
        // see who won 
        bool landedColorEven = (roll > 0 && roll < 37);
        // sides
        bool even; bool red; uint256 third;
        if (landedColorEven) {
            // check even/odd red/black thirds winners
            even = isEven(roll);
            red = isRed[roll];
            third = whichThird(roll);
        }
        for (uint i = 0; i < players.length; i++) {
            address player = players[i];
            if (landedColorEven) {
                if (participants[player].betOnColor && participants[player].red == red) {
                    participants[player].winnings += participants[player].amountBetOnColor.mul(evenOddsPayOut);
                }
                if (participants[player].betOnEvens && participants[player].evens == even) {
                    participants[player].winnings += participants[player].amountBetOnEven.mul(evenOddsPayOut);
                }
                if (participants[player].betOnThirds && participants[player].whichThird == third) {
                    participants[player].winnings += participants[player].amountBetOnThirds.mul(thirdsPayOut);
                }
            }
            for (uint j = 0; j < participants[player].nums.length; j++) {
                if (roll == participants[player].nums[j]) {
                    participants[player].winnings += participants[player].betVals[j].mul(numberPayOut);
                    break;
                }
            }
            if (participants[player].winnings > 0) {
                buyToken(preferedToken[player], player, participants[player].winnings);
                emit Winner(player, participants[player].winnings);
            }
        }
        // delete player structures
        for (uint i = 0; i < players.length; i++) {
            delete participants[players[i]];
        }
        //bool even = isEven(roll);
        delete players;
        gameIsOn = false;
    }
    
    receive() external payable {
        if (isInjector[msg.sender]) return;
        require(!_gameHalted, 'Game Has Been Halted');
        require(isApproved[msg.sender], 'Sender Not Approved');
        require(!gameCanBeEnded(), 'Game Is Waiting For Closure');
        require(msg.value >= minBet, 'Under Minimum Bet');
        require(players.length <= maxPlayersPerGame, 'Too Many Players');
        participants[msg.sender].totalBet += msg.value;
        require(participants[msg.sender].totalBet <= maxBet, 'Over Maximum Bet');
        if (!includes(players, msg.sender)) {
            players.push(msg.sender);
        }
        if (!gameIsOn) {
            gameIsOn = true;
            gameStartTime = block.number;
        }
        salt += (msg.value + block.timestamp) / 10**6;
    }
}