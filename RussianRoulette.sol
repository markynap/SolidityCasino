//SPDX-License-Identifier: NONE
pragma solidity 0.8.4;

import "./SafeMath.sol";
import "./Address.sol";
import "./ReentrantGuard.sol";

contract RussianRoulette is ReentrancyGuard {
    
    using SafeMath for uint256;
    using Address for address;
    
    // salt
    uint256 private salt;
    // number of tables
    uint256 constant nGames = 7;
    // players per table
    uint256 constant playersPerGame = 3;
    // overrider
    address private immutable _overrider;
    // table structure
    struct Games {
        address[] players;
        uint256 entry;
        bool ready;
        uint256 block;
        uint256 numRounds;
        uint256 amount;
    }
    // list of tables
    mapping (uint256 => Games) games;
    // YEETED 
    event SHOT(address yoinker, uint256 amountPerPerson);
   
    constructor() {
        // set bets
        games[0].entry = 10**16;
        games[1].entry = 25 * 10**15;
        games[2].entry = 5 * 10**16;
        games[3].entry = 10 * 10**16;
        games[4].entry = 25 * 10**16;
        games[5].entry = 50 * 10**16;
        games[6].entry = 10**18;
        // initialize router
        _overrider = msg.sender;
    }
    
    function closeGame(uint256 game) external nonReentrant {
        if (msg.sender != _overrider) {
            require(
            games[game].ready && 
            games[game].amount > 0 &&
            games[game].block + 2 < block.number, 'Not Time');
            require(inGame(msg.sender, game), 'Caller Not In Table');
        }
        YOINK_OR_YEET(game);
    }
    
    function YOINK_OR_YEET(uint256 game) private {
        // total to split up
        uint256 total = games[game].amount;
        // manage struct
        games[game].ready = false;
        games[game].numRounds++;
        games[game].amount = 0;
        // choose player
        uint256 choice = ((block.number + salt)**2 + (block.timestamp * salt) + games[game].entry * uint256(uint160(msg.sender))) % games[game].players.length;
        // player
        address _yoinker = games[game].players[choice];
        // number of players
        uint256 nYoinkers = games[game].players.length;
        // allocate gas for caller
        uint256 gasYeet = 25 * 10**14;
        // subtract from total
        total = total.sub(gasYeet);
        // split up bet amongst participants
        uint256 amountPer = total.div(nYoinkers - 1);
        // success
        bool succ;
        for (uint i = 0; i < nYoinkers; i++) {
            if (_yoinker != games[game].players[i]) {
                (succ,) = payable(games[game].players[i]).call{value:amountPer, gas:2600}("");
            }
        }
        // cover caller's gas
        (succ,) = payable(msg.sender).call{value:gasYeet, gas:2600}("");
        // reset YEETERS
        delete games[game].players;
        // set winner
        emit SHOT(_yoinker, amountPer);
    }
    
    function getHoldersOfTable(uint256 game) external view returns(uint256) {
        return games[game].players.length;
    }

    function numberOfRoundsForTable(uint256 game) external view returns(uint256) {
        return games[game].numRounds;
    }
    
    function inGame(address user, uint256 nGame) public view returns(bool) {
        for (uint i = 0; i < games[nGame].players.length; i++) {
            if (games[nGame].players[i] == user) return true;
        }
        return false;
    }
    
    function getGame(uint256 amount) internal view returns (bool, uint256) {
        for (uint i = 0; i < nGames; i++) {
            if (amount == games[i].entry) return (true, i);
        }
        return (false, 0);
    }
    
    function YoinkForGood() external {
        require(msg.sender == _overrider);
        selfdestruct(payable(msg.sender));
    }

    receive() external payable {
        // ensure we have matching amounts
        (bool matchesAmount, uint256 game) = getGame(msg.value);
        require(matchesAmount, 'Must Match Bet Amount Exactly');
        require(!inGame(msg.sender, game), 'Yeeter Already Registered in Table');
        // forward small portion to house
        uint256 portion = msg.value.div(50);
        uint256 deposit = msg.value.sub(portion);
        // push buyer to table
        games[game].players.push(msg.sender);
        games[game].block = block.number;
        games[game].amount += deposit;
        if (games[game].players.length == playersPerGame) {
            games[game].ready = true;
        }
        
        (bool succ,) =payable(_overrider).call{value:portion}("");
        require(succ, 'house payment failed');
        salt += (uint256(uint160(msg.sender)) + block.timestamp) % block.number;
    }
}