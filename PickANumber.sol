//SPDX-License-Identifier: NONE
pragma solidity 0.8.4;

contract PickANumber {
    
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
    mapping (address => uint256) _claim;
    mapping (address => uint256) _claimTime;
    uint256 constant max = 11;
    address immutable private seeder;
    uint256 private salt;
    event NumberChosen(uint256 choice, uint256 number, uint256 claim);
    constructor(){seeder = msg.sender;_status = _NOT_ENTERED;}
    
    function pickANumberAndRange(uint256 number, uint256 range) external nonReentrant {
        require(number > 0 && number < range && range > 2, 'Out Of Range');
        require(_claimTime[msg.sender] + 2 < block.number, 'Too Soon');
        uint256 claim = _claim[msg.sender];
        require(claim > 0);
        _claim[msg.sender] = 0;
        uint256 choice = ((block.number + salt)**2 + (block.timestamp * salt) + claim + uint256(uint160(msg.sender))) % range;
        uint256 winning = (range-1)*claim;
        winning = winning > address(this).balance ? address(this).balance : winning;
        if (number == choice) {
            (bool s,) = payable(msg.sender).call{value: winning, gas:2600}("");
            require(s, 'Failure On Transfer');
            emit NumberChosen(choice, number, winning);
        } else {
            emit NumberChosen(choice, number, 0);
        }
    }
    
    function pickANumber(uint256 number) external nonReentrant {
        require(number > 0 && number < max, 'Out Of Range');
        require(_claimTime[msg.sender] + 2 < block.number, 'Too Soon');
        uint256 claim = _claim[msg.sender];
        require(claim > 0);
        _claim[msg.sender] = 0;
        uint256 choice = ((block.number + salt)**2 + (block.timestamp * salt) + claim + uint256(uint160(msg.sender))) % max;
        uint256 winning = 10*claim;
        winning = winning > address(this).balance ? address(this).balance : winning;
        if (number == choice) {
            (bool s,) = payable(msg.sender).call{value: winning, gas:2600}("");
            require(s, 'Failure On Transfer');
            emit NumberChosen(choice, number, winning);
        } else {
            emit NumberChosen(choice, number, 0);
        }
    }
    
    function withdrawClaim() external nonReentrant {
        uint256 claim = _claim[msg.sender];
        require(claim > 0, 'Zero Claim');
        _claim[msg.sender] = 0;
        (bool s,) = payable(msg.sender).call{value: claim, gas:2600}("");
        require(s, 'Failure On Withdrawal');
    }
    
    function destroy() external {
        require(msg.sender == seeder);
        selfdestruct(payable(msg.sender));
    }
    
    receive() external payable {
        _claim[msg.sender] += msg.value;
        _claimTime[msg.sender] = block.number;
        salt += (msg.value + block.timestamp + uint256(uint160(msg.sender))) % block.number;
    }
    
}