// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract ChainlinkOracle {
    AggregatorV3Interface internal priceFeed;

    /**
     * Network: Sepolia / Ethereum Mainnet
     * Aggregator: ETH/USD
     * Address for Sepolia: 0x694AA1769357215DE4FAC081bf1f309aDC325306
     * Address for Mainnet: 0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419
     */
    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice() public view returns (int256) {
        (
            , 
            int256 price,
            ,
            ,
            
        ) = priceFeed.latestRoundData(); // @audit Do NOT use .latestAnswer()
        return price;
    }

    /**
     * Returns additional data: round ID, timestamp, etc.
     */
    function getRoundData() public view returns (
        uint80 roundId,
        int256 price,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return priceFeed.latestRoundData();
    }
}