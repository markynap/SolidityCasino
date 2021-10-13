//SPDX-License-Identifier: NONE
pragma solidity 0.8.4;

import "./IERC20.sol";
import "./SafeMath.sol";
import "./Address.sol";
import "./IUniswapV2Router02.sol";

/**
 *                      _       __                                    __ ___ 
 *        __  ______  (_)___  / /__   ____  _____   __  _____  ___  / //__ \
 *      / / / / __ \/ / __ \/ //_/  / __ \/ ___/  / / / / _ \/ _ \/ __// _/
 *    / /_/ / /_/ / / / / / ,<    / /_/ / /     / /_/ /  __/  __/ /_ /_/  
 *   \__, /\____/_/_/ /_/_/|_|   \____/_/      \__, /\___/\___/\__/(_)   
 * /____/                                    /____/      
 * 
 */
contract YoinkOrYeet {
    
    using SafeMath for uint256;
    using Address for address;
    
    // useless CA for default
    address constant _default = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    // PCS router
    IUniswapV2Router02 immutable router;
    // salt
    uint256 private salt;
    // number of tables
    uint256 constant nTables = 7;
    // overrider
    address private immutable _overrider;
    // table structure
    struct Table {
        address[] yeeters;
        uint256 bet;
        uint256 deadline;
        uint256 roundTimer;
        bool startYeet;
        uint256 blockBet;
        uint256 bnbToYeet;
        address awardToken;
        uint256 numRounds;
        bool awardTokenChanged;
    }
    // list of tables
    mapping (uint256 => Table) tables;
    // list of users to winnings
    mapping (address => uint256) winnings;
    // YEETED 
    event YEETED(address yoinker, uint256 yoinkings, address tokenYoinked);
   
    constructor() {
        // set bets
        tables[0].bet = 10**16;
        tables[1].bet = 25 * 10**15;
        tables[2].bet = 5 * 10**16;
        tables[3].bet = 10 * 10**16;
        tables[4].bet = 25 * 10**16;
        tables[5].bet = 50 * 10**16;
        tables[6].bet = 10**18;
        // set deadlines
        tables[0].deadline = 1 * 20;
        tables[1].deadline = 2 * 20;
        tables[2].deadline = 2 * 20;
        tables[3].deadline = 2 * 20;
        tables[4].deadline = 3 * 20;
        tables[5].deadline = 4 * 20;
        tables[6].deadline = 5 * 20;
        // initialize router
        router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        _overrider = msg.sender;
    }
    
    function closeTable(uint256 table) external {
        if (msg.sender != _overrider) {
            require(
            tables[table].startYeet && 
            tables[table].roundTimer + tables[table].deadline < block.number &&
            tables[table].blockBet + 2 < block.number, 'Not Time');
            require(inTable(msg.sender, table), 'Caller Not In Table');
        }
        YOINK_OR_YEET(table);
    }
    
    function setAwardToken(uint256 table, address award) external {
        if (msg.sender != _overrider) {
            require(tables[table].roundTimer + tables[table].deadline < block.number, 'Duration Has Ended');
            require(inTable(msg.sender, table), 'User Not In Table');
            require(!tables[table].awardTokenChanged, 'Cannot Change Twice Per Round');
        }
        tables[table].awardToken = award;
        tables[table].awardTokenChanged = true;
    }
    
    function YOINK_OR_YEET(uint256 table) private {
        uint256 roll = (salt*(block.timestamp**2 % block.number) + block.number) % tables[table].yeeters.length;
        // yeeter
        address _yoinker = tables[table].yeeters[roll];
        // bnb to yeet
        uint256 bnbForYeet = tables[table].bnbToYeet;
        // false the yeet
        tables[table].startYeet = false;
        tables[table].bnbToYeet = 0;
        tables[table].numRounds++;
        tables[table].awardTokenChanged = false;
        uint256 gasYeet = 4 * 10**15;
        // cover caller's gas
        (bool suc,) =payable(msg.sender).call{value:gasYeet, gas:2600}("");
        if(suc){
            bnbForYeet -= gasYeet;
        }
        // increment winnings
        winnings[_yoinker] += bnbForYeet;
        // reset YEETERS
        delete tables[table].yeeters;
        // token
        address token = getAwardTokenForTable(table);
        // buy token
        buyToken(token, _yoinker, bnbForYeet);
        // set winner
        emit YEETED(_yoinker, bnbForYeet, token);
    }
    
    function buyToken(address _token, address winner, uint256 bnb) internal {
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
    
    function getBalanceOfTable(uint256 table) external view returns(uint256) {
        return tables[table].bnbToYeet;
    }
    
    function getHoldersOfTable(uint256 table) external view returns(uint256) {
        return tables[table].yeeters.length;
    }
        
    function getAwardTokenForTable(uint256 table) public view returns(address){
        address award = tables[table].awardToken;
        return award == address(0) ? _default : award;
    }
    
    function blocksLeftTillClose(uint256 table) external view returns(uint256) {
        if (tables[table].roundTimer + tables[table].deadline >= block.number) {
            return 0;
        } else {
            return block.number.sub(tables[table].roundTimer + tables[table].deadline);
        }
    }
    
    function numberOfRoundsForTable(uint256 table) external view returns(uint256) {
        return tables[table].numRounds;
    }
    
    function getWinningsForUser(address _user) external view returns(uint256) {
        return winnings[_user];
    }
    
    function inTable(address user, uint256 nTable) public view returns(bool) {
        for (uint i = 0; i < tables[nTable].yeeters.length; i++) {
            if (tables[nTable].yeeters[i] == user) return true;
        }
        return false;
    }
    
    function getTable(uint256 amount) internal view returns (bool, uint256) {
        for (uint i = 0; i < nTables; i++) {
            if (amount == tables[i].bet) return (true, i);
        }
        return (false, 0);
    }
    
    function YoinkForGood() external {
        require(msg.sender == _overrider);
        selfdestruct(payable(msg.sender));
    }

    receive() external payable {
        // ensure we have matching amounts
        (bool matchesAmount, uint256 table) = getTable(msg.value);
        require(matchesAmount, 'Must Match Bet Amount Exactly');
        require(!inTable(msg.sender, table), 'Yeeter Already Registered in Table');
        // forward small portion to house
        uint256 portion = msg.value.div(50);
        uint256 deposit = msg.value.sub(portion);
        // push buyer to table
        tables[table].yeeters.push(msg.sender);
        tables[table].blockBet = block.number;
        tables[table].bnbToYeet += deposit;

        if (tables[table].yeeters.length == 2) {
            tables[table].startYeet = true;
            tables[table].roundTimer = block.number;
            salt += (block.number**2 + block.timestamp).div(37);
        }
        
        (bool suc,) =payable(_overrider).call{value:portion}("");
        require(suc, 'house payment failed');
    }
}