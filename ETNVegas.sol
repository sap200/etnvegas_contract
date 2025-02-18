// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract ETNVegas {

    // Mapping of user's address and their token balance
    address public owner;
    mapping(address => uint256) private users;
    mapping(address => bool) private registered;
    uint256 public totalUsers;
    uint256 public TOKEN_BUY_PRICE = 0.002 ether;
    uint256 public TOKEN_SELL_PRICE = 0.0014 ether;
    uint256 public FEE_PERCENTAGE = 1;
    uint256 private HOUSE_PROFIT_PERCENTAGE = 5;
    uint256 private house_profit;
    uint256 private fees_collected;
    uint256 private total_tokens_supply;
    uint256 private JACKPOT_NUMBER = 10;

    uint256 private SOURCE_NONCE_1 = 0x494B41B3;
    uint256 private SOURCE_NONCE_2 = 0x494B41B3;
    uint256 private SOURCE_NONCE_3 = 0x1EF15EB;
    uint256 private PRIME_INCREMENTOR = 3;
    uint256 private MAX_UINT256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // 2^256-1


    event ChipBought(address indexed buyer, uint256 amount);
    event ExchangedChip(address indexed withdrawer, uint256 amount);
    event SlotGameResultOut(address indexed player, uint256[4] result);
    event SpinResultOut(address indexed player, uint256 choice, uint256 spinNumber);
    event DiceRollResultOut(address indexed player, uint256 choice, uint256 diceNumber);
    event HousingProfitWithdrawn(address indexed beneficiary, uint256 amount);
    event RouletteGameResultOut(address indexed player, uint256 spinResult, uint256 payoutPlus, uint256 payoutMinus, uint256 totalBet, uint256 afterDeduction, uint256 finalBalance);

    // Mappings 
    mapping(uint256 => bool) private blackNumbers;
    mapping(uint256 => bool) private redNumbers;
    mapping(uint256 => bool) private col34;
    mapping(uint256 => bool) private col35;
    mapping(uint256 => bool) private col36;


    constructor() public payable {
        owner = msg.sender;


        // for black
        uint8[18] memory black = [2, 4, 6, 8, 10, 11, 13, 15, 17, 20, 22, 24, 26, 28, 29, 31, 33, 35];
        for (uint256 i = 0; i < black.length; i++) {
            blackNumbers[uint256(black[i])] = true;
        }

        

        // for red
        uint8[18] memory red = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36];
        for (uint256 i = 0; i < red.length; i++) {
            redNumbers[uint256(red[i])] = true;
        }


        uint8[12] memory co34 = [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34];
        for (uint256 i = 0; i < co34.length; i++) {
            col34[uint256(co34[i])] = true;
        }


        uint8[12] memory co35 = [2, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35];
        for (uint256 i = 0; i < co35.length; i++) {
            col35[uint256(co35[i])] = true;
        }


        uint8[12] memory co36 = [3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36];
        for (uint256 i = 0; i < co36.length; i++) {
            col36[uint256(co36[i])] = true;
        }

    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    function buyToken() external payable {
        require(msg.value >= TOKEN_BUY_PRICE, "Sent value is less than minimum");

        // Register user on first deposit
        if(!registered[msg.sender]) {
            totalUsers++;
            registered[msg.sender] = true;
        }

        uint256 tokensBought = msg.value / TOKEN_BUY_PRICE;
        total_tokens_supply += tokensBought;
        house_profit += msg.value*HOUSE_PROFIT_PERCENTAGE/100; // 10 percent of msg.value
        users[msg.sender] += tokensBought;

        emit ChipBought(msg.sender, tokensBought);
    }

    function setNonceSources(uint256 _s1, uint256 _s2, uint256 _s3, uint256 _in) external onlyOwner {
        SOURCE_NONCE_1 = _s1;
        SOURCE_NONCE_2 = _s2;
        SOURCE_NONCE_3 = _s3;
        PRIME_INCREMENTOR = _in;
    }

    function setJackPotNumber(uint256 _jn) external onlyOwner {
        JACKPOT_NUMBER = _jn;
    }

    function getTotalHouseFunds() internal view returns(uint256) {
        return address(this).balance;
    }

    function getTotalHouseProfit() internal  view returns(uint256) {
        return house_profit+fees_collected;
    }

   function getHouseProfitTillNowForAdmin() external onlyOwner view returns(uint256) {
        return house_profit+fees_collected;
    }

    function getFreeFloatingCapital() internal view  returns(uint256) {
        return getTotalHouseFunds() - getTotalHouseProfit();
    }

    function getFreeFloatingCapitalForAdmin() external view onlyOwner  returns(uint256) {
        return getTotalHouseFunds() - getTotalHouseProfit();
    }

    function setTokenBuyPrice(uint256 value) external onlyOwner {
        require(value != 0, "Invalid value");
        TOKEN_BUY_PRICE = value;
    }

    function setTokenSellPrice(uint256 value) external onlyOwner {
        require(value != 0, "Invalid value");
        TOKEN_SELL_PRICE = value;
    }

    function setFeePercentage(uint256 value) external onlyOwner {
        require(value != 0, "Invalid value");
        FEE_PERCENTAGE = value;
    }

    function getUserTokenBalance() external view returns (uint256) {
        return users[msg.sender];
    }

    function withdrawHousingProfit(address beneficiary, uint256 amount) external onlyOwner {
        require( getTotalHouseProfit() >= amount, "Insufficient balance");
        // modify house_profit
        if(amount <= house_profit) {
            house_profit -= amount;
        } else if (amount <= fees_collected) {
            fees_collected -= amount;
        } else {
            uint256 remaining = house_profit+fees_collected-amount;
            house_profit = remaining;
            fees_collected = 0;
        }
        // Following Checks-Effects-Interactions pattern
        payable(beneficiary).transfer(amount);
        emit HousingProfitWithdrawn(owner, amount);
    }

    function countSimilarInSlots(uint256[3] memory x) internal pure returns (uint256) {
        if (x[0] == x[1] && x[1] == x[2]) {
            return 3;
        } else if (x[0] == x[1] || x[0] == x[2] || x[1] == x[2]) {
            return 2;
        } else {
            return 0;
        }
    }



    function exchangeWithEther(uint256 token) external {
        require(token != 0, "Token is 0");
        require(users[msg.sender] >= token, "Insufficient token balance");

        uint256 amountToBeGiven = token * TOKEN_SELL_PRICE;
        require(amountToBeGiven <= getFreeFloatingCapital(), "amount exceeds liabilities");
        uint256 fees = (amountToBeGiven * FEE_PERCENTAGE / 100);
        uint256 amountToBeGivenDeductingFee = amountToBeGiven - fees;

        require(amountToBeGivenDeductingFee <= getFreeFloatingCapital(), "Insufficient contract balance");
        // Update state before interacting with external addresses
        users[msg.sender] -= token;
        total_tokens_supply -= token;
        fees_collected += fees;

        // Transfer Ether to the beneficiary
        payable(msg.sender).transfer(amountToBeGivenDeductingFee);
        emit ExchangedChip(msg.sender, amountToBeGivenDeductingFee);
    }

    function getEtherExchangeAmount(uint256 token) external view returns(uint256) {
        require(token != 0, "Token is 0");
        require(users[msg.sender] >= token, "Insufficient token balance");

        uint256 amountToBeGiven = token * TOKEN_SELL_PRICE;
        require(amountToBeGiven <= getFreeFloatingCapital(), "amount exceeds liabilities");
        uint256 fees = (amountToBeGiven * FEE_PERCENTAGE / 100);
        uint256 amountToBeGivenDeductingFee = amountToBeGiven - fees;

        require(amountToBeGivenDeductingFee <= getFreeFloatingCapital(), "Insufficient contract balance");
        // Update state before interacting with external addresses
        return amountToBeGivenDeductingFee;
    }

    function playSlots(uint256 betAmount, uint256 _randomnessSource1, uint256 _randomnessSource2, uint256 _randomnessSource3) external returns (uint256[4] memory) {
        require(betAmount >= 1, "Bet amount should be more than 1");
        require(users[msg.sender] >= betAmount, "Insufficient token balance");

        // Reduce balance before external interactions (Checks-Effects-Interactions pattern)
        users[msg.sender] -= betAmount;

        uint256[3] memory x;
        x[0] = generateRandomNumber(_randomnessSource1, JACKPOT_NUMBER);
        x[1] = generateRandomNumber(_randomnessSource2, JACKPOT_NUMBER);
        x[2] = generateRandomNumber(_randomnessSource3, JACKPOT_NUMBER);

        uint256[4] memory result;
        uint256 similar = countSimilarInSlots(x);
        
        result[0] = x[0];
        result[1] = x[1];
        result[2] = x[2];
        result[3] = (similar != 0) ? 1 : 0;

        emit SlotGameResultOut(msg.sender, result);

        if(similar == 2 || similar == 3) {
            users[msg.sender] += betAmount*(similar+1);
            total_tokens_supply += betAmount * similar;
        } else {
            total_tokens_supply -= betAmount;

        }


        return result;
    }

    function spinTheWheel(uint256 betAmount, uint256 choice, uint256 _randomnessSource1) external returns (uint256) {
        require(betAmount >= 1 , "Bet amount should be more than 1");
        require(users[msg.sender] >= betAmount, "Insufficient token balance");
        require(choice >= 1 && choice <= JACKPOT_NUMBER, "Invalid chocie");

        // Reduce balance before external interactions (Checks-Effects-Interactions pattern)
        users[msg.sender] -= betAmount;

        // spin the wheel
        uint256 spinWheelResult = generateRandomNumber(_randomnessSource1, JACKPOT_NUMBER);
        if (choice == spinWheelResult) {
            // won
            // choice is 2, 3, 5, 7
            users[msg.sender] += betAmount*(choice+1);
            total_tokens_supply += betAmount*choice;
        } else {
            total_tokens_supply -= betAmount;
        }
        
        emit SpinResultOut(msg.sender, choice, spinWheelResult);
        return spinWheelResult;

    }

    function rollADice(uint256 betAmount, uint256 choice, uint256 _randomnessSource1) external returns (uint256) {
        uint256 DICE_NUMBER_MAX = 6;
        require(betAmount >= 1 , "Bet amount should be more than 1");
        require(users[msg.sender] >= betAmount, "Insufficient token balance");
        require(choice >= 1 && choice <= DICE_NUMBER_MAX, "Invalid chocie");

        // Reduce balance before external interactions (Checks-Effects-Interactions pattern)
        users[msg.sender] -= betAmount;
        uint256 diceRollResult = generateRandomNumber(_randomnessSource1, DICE_NUMBER_MAX);
        if(choice == diceRollResult) {
            users[msg.sender] += betAmount*(choice+1);
            total_tokens_supply += betAmount*choice;
        } else {
            total_tokens_supply -= betAmount;
        }

        emit DiceRollResultOut(msg.sender, choice, diceRollResult);
        return diceRollResult;
    }

    function getPayoutMultiplier(uint256 idx) internal pure returns (uint256) {
        if (idx >= 0 && idx <= 36) {
            return 35;
        } else if (idx == 37 || idx == 38 || idx == 39) {
            return 2;
        } else if (idx == 40 || idx == 41 || idx == 42) {
            return 2;
        } else if (idx == 43 || idx == 44) {
            return 1;
        } else if (idx == 45 || idx == 46) {
            return 1;
        } else if (idx == 47 || idx == 48) {
            return 1;
        }
    }

    function getSumOfAllBets(uint256[] memory bets) internal pure returns(uint256) {
        uint256 sum = 0;
        for(uint256 i = 0; i < 49; i++) {
            sum += bets[i];
        }

        return sum;

    }


    function playRoulette(uint256[] memory bets, uint256 _randomnessSource1) external returns(uint256) {
        uint256 sum = getSumOfAllBets(bets);
        require(users[msg.sender] >= sum, "Invalid bets");
        users[msg.sender] -= sum;
        total_tokens_supply -= sum;
        uint256 spinNumber = generateRandomNumberRoulette(_randomnessSource1);
        uint256 payoutPlus = 0;
        uint256 payoutMinus = 0;
        // 0 to 36 category
        for(uint256 i = 0; i <= 36; i++) {
            if(bets[i] > 0) {
                if(spinNumber == i) {
                    payoutPlus = payoutPlus + ((getPayoutMultiplier(i) + 1) * bets[i]);
                } else {
                    payoutMinus = payoutMinus + (bets[i]);
                }
            }
        }

        // special category : column bet
        if(bets[37] > 0) {
            bool res = col34[spinNumber];
            if(res) {
                payoutPlus = payoutPlus + (getPayoutMultiplier(37) + 1) * bets[37] ;
            } else {
                payoutMinus = payoutMinus + bets[37];
            }
        }

        if(bets[38] > 0) {
            bool res = col35[spinNumber];
            if(res) {
                payoutPlus = payoutPlus + ( (getPayoutMultiplier(38) + 1) * bets[38] );
            } else {
                payoutMinus = payoutMinus + (bets[38]);
            }
        }
        
        if(bets[39] > 0) {
            bool res = col36[spinNumber];
            if(res) {
                payoutPlus = payoutPlus + ( (getPayoutMultiplier(39) + 1) * bets[39] );
            } else {
                payoutMinus = payoutMinus + (bets[39]);
            }
        }

        if(bets[40] > 0) {
            if(spinNumber >= 1 && spinNumber <= 12) {
                payoutPlus = payoutPlus + ( (getPayoutMultiplier(40) + 1) * bets[40] );
            } else {
                payoutMinus = payoutMinus + (bets[40]);
            }
        }

        if(bets[41] > 0) {
            if(spinNumber >= 13 && spinNumber <= 24) {
                payoutPlus = payoutPlus + ( (getPayoutMultiplier(41) + 1) * bets[41] );
            } else {
                payoutMinus = payoutMinus + (bets[41]);
            }
        }

        if(bets[42] > 0) {
            if(spinNumber >= 25 && spinNumber <= 36) {
                payoutPlus = payoutPlus + ( (getPayoutMultiplier(42) + 1) * bets[42] );
            } else {
                payoutMinus = payoutMinus + (bets[42]);
            }
        }

        if(bets[43] > 0) {
            if(spinNumber >= 1 && spinNumber <= 18) {
                payoutPlus = payoutPlus + ( (getPayoutMultiplier(43) + 1) * bets[43] );
            } else {
                payoutMinus = payoutMinus + (bets[43]);
            }
        }

        if(bets[44] > 0) {
            if(spinNumber >= 19 && spinNumber <= 36) {
                payoutPlus = payoutPlus + ( (getPayoutMultiplier(44) + 1) * bets[44] );
            } else {
                payoutMinus = payoutMinus + (bets[44]);
            }
        }

        if(bets[45] > 0) {
            if(spinNumber % 2 == 0) {
                payoutPlus = payoutPlus + ( (getPayoutMultiplier(45) + 1) * bets[45] );
            } else {
                payoutMinus = payoutMinus + (bets[45]);
            }
        }


        if(bets[46] > 0) {
            if(spinNumber % 2 != 0) {
                payoutPlus = payoutPlus + ( (getPayoutMultiplier(46) + 1) * bets[46] );
            } else {
                payoutMinus = payoutMinus + (bets[46]);
            }
        }

        
        if(bets[47] > 0) {
            if(redNumbers[spinNumber]) {
                payoutPlus = payoutPlus + ( (getPayoutMultiplier(47) + 1) * bets[47] );
            } else {
                payoutMinus = payoutMinus + (bets[47]);
            }
        }

        if(bets[48] > 0) {
            if(blackNumbers[spinNumber]) {
                payoutPlus = payoutPlus + ( (getPayoutMultiplier(48) + 1) * bets[48] );
            } else {
                payoutMinus = payoutMinus + (bets[48]);
            }
        }

        uint256 beforeBet = users[msg.sender];
        users[msg.sender] = users[msg.sender] + payoutPlus;
        total_tokens_supply = total_tokens_supply + payoutPlus;

        emit RouletteGameResultOut(msg.sender, spinNumber, payoutPlus, payoutMinus, sum, beforeBet, users[msg.sender]);
        
        return users[msg.sender];
        
    }


    function generateRandomNumber(uint256 src, uint256 modulus) internal  returns (uint256) {
        uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, src, SOURCE_NONCE_1, SOURCE_NONCE_2, SOURCE_NONCE_3, msg.sender))) % modulus;
        if(SOURCE_NONCE_1 >= MAX_UINT256 - PRIME_INCREMENTOR - 1) {
            // reset
            SOURCE_NONCE_1 = 0x494B41B3;
        }

        if(SOURCE_NONCE_2 >= MAX_UINT256 - PRIME_INCREMENTOR - 1) {
            // reset
            SOURCE_NONCE_2 = 0x494B41B3;
        }

        if(SOURCE_NONCE_3 >= MAX_UINT256 - PRIME_INCREMENTOR - 1) {
            // reset
            SOURCE_NONCE_3 = 0x1EF15EB;
        }

        SOURCE_NONCE_1 += PRIME_INCREMENTOR;
        SOURCE_NONCE_2 += PRIME_INCREMENTOR;
        SOURCE_NONCE_3 += PRIME_INCREMENTOR;
        return random+1;
    }

    function generateRandomNumberRoulette(uint256 src) internal  returns (uint256) {
        uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, src, SOURCE_NONCE_1, SOURCE_NONCE_2, SOURCE_NONCE_3, msg.sender))) % 37;
        if(SOURCE_NONCE_1 >= MAX_UINT256 - PRIME_INCREMENTOR - 1) {
            // reset
            SOURCE_NONCE_1 = 0x494B41B3;
        }

        if(SOURCE_NONCE_2 >= MAX_UINT256 - PRIME_INCREMENTOR - 1) {
            // reset
            SOURCE_NONCE_2 = 0x494B41B3;
        }

        if(SOURCE_NONCE_3 >= MAX_UINT256 - PRIME_INCREMENTOR - 1) {
            // reset
            SOURCE_NONCE_3 = 0x1EF15EB;
        }

        SOURCE_NONCE_1 += PRIME_INCREMENTOR;
        SOURCE_NONCE_2 += PRIME_INCREMENTOR;
        SOURCE_NONCE_3 += PRIME_INCREMENTOR;
        return random;
    }


    function changeOwner(address _newOwner) external onlyOwner {
        owner = _newOwner;
    }


    function getTotalTokenSupply() external view onlyOwner returns (uint256) {
        return total_tokens_supply;
    }

    receive() external payable {
    }

    fallback() external payable {
    }
}
