// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title BoxV1
 * @dev Implementación V1 usada por los patrones Transparent y Beacon. Acá la
 *      lógica de upgrade NO vive en el contrato (vive en el proxy o en el
 *      beacon), por eso la implementación ni se entera de que es "upgradeable":
 *      lo único especial es que usa un `initialize` en vez de constructor,
 *      porque el constructor correría en el contexto de la implementación, no
 *      del proxy, y el storage del proxy quedaría sin inicializar.
 */
contract BoxV1 is Initializable, OwnableUpgradeable {
    uint256 public value;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers(); // la implementación nunca se usa de forma directa
    }

    /// @notice Inicializa el estado a través del proxy (reemplaza al constructor)
    function initialize(uint256 value_) public initializer {
        __Ownable_init(msg.sender);
        value = value_;
    }

    function store(uint256 value_) external {
        value = value_;
    }

    function version() external pure virtual returns (string memory) {
        return "V1";
    }
}
