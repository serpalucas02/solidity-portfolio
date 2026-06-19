// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title BoxV2
 * @dev Nueva versión de la lógica para Transparent y Beacon. Clave del storage
 *      layout: `value` se mantiene en el MISMO slot que en V1; las variables
 *      nuevas (si las hubiera) irían DESPUÉS, nunca antes ni en el medio, para
 *      no pisar el estado existente. Acá solo agregamos una función nueva.
 */
contract BoxV2 is Initializable, OwnableUpgradeable {
    uint256 public value;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 value_) public initializer {
        __Ownable_init(msg.sender);
        value = value_;
    }

    function store(uint256 value_) external {
        value = value_;
    }

    /// @notice Funcionalidad NUEVA que no existía en V1
    function increment() external {
        value += 1;
    }

    function version() external pure returns (string memory) {
        return "V2";
    }
}
