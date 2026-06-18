// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract SecureChainlinkOracle {
    AggregatorV3Interface public immutable primaryPriceFeed;
    AggregatorV3Interface public immutable secondaryPriceFeed;
    uint256 public immutable staleFeedThreshold; // in seconds

    constructor(
        address _primaryFeed,
        address _secondaryFeed,
        uint256 _staleThreshold
    ) {
        require(_primaryFeed != address(0), "Primary feed address required");
        require(_secondaryFeed != address(0), "Secondary feed address required");
        require(_staleThreshold > 0, "Stale threshold must be positive");

        primaryPriceFeed = AggregatorV3Interface(_primaryFeed);
        secondaryPriceFeed = AggregatorV3Interface(_secondaryFeed);
        staleFeedThreshold = _staleThreshold;
    }

    function getLatestPrice() external view returns (int256 price, uint8 decimals) {
        try primaryPriceFeed.latestRoundData() {
            (
                uint80 roundId,
                int256 answer,
                uint256 startedAt,
                uint256 updatedAt,
                uint80 answeredInRound
            ) = primaryPriceFeed.latestRoundData();

            require(answer > 0, "Primary feed: price <= 0");
            require(updatedAt > 0, "Primary feed: invalid timestamp");
            require(block.timestamp - updatedAt <= staleFeedThreshold, "Primary feed: stale");

            price = answer;
            decimals = primaryPriceFeed.decimals();
        } catch {
            try secondaryPriceFeed.latestRoundData() {
                (
                    uint80 roundId,
                    int256 answer,
                    uint256 startedAt,
                    uint256 updatedAt,
                    uint80 answeredInRound
                ) = secondaryPriceFeed.latestRoundData();

                require(answer > 0, "Secondary feed: price <= 0");
                require(updatedAt > 0, "Secondary feed: invalid timestamp");
                require(block.timestamp - updatedAt <= staleFeedThreshold, "Secondary feed: stale");

                price = answer;
                decimals = secondaryPriceFeed.decimals();
            } catch {
                revert("Both price feeds failed");
            }
        }
    }

    function getDecimals() external view returns (uint8) {
        return primaryPriceFeed.decimals();
    }

    function getPriceFeedAddress() external view returns (address) {
        return address(primaryPriceFeed);
    }
}
