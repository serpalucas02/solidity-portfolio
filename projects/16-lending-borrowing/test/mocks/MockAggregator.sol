// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../src/interfaces/IAggregator.sol";

/**
 * @dev Mock de un price feed de Chainlink. El precio se setea en el constructor
 *      y se puede cambiar con `setPrice` (clave para forzar liquidaciones bajando
 *      el valor del colateral). El answer va en 8 decimales, como los feeds USD.
 */
contract MockAggregator is IAggregator {
    int256 public price;

    constructor(int256 price_) {
        price = price_;
    }

    function setPrice(int256 price_) external {
        price = price_;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (1, price, block.timestamp, block.timestamp, 1);
    }
}
