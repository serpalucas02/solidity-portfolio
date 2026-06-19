// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title BoxUUPSV1
 * @dev Implementación V1 para el patrón UUPS. A diferencia de Transparent/Beacon,
 *      en UUPS la lógica de upgrade vive EN LA PROPIA IMPLEMENTACIÓN (hereda
 *      UUPSUpgradeable). El hook `_authorizeUpgrade` decide quién puede
 *      actualizar — si una versión futura se olvida de incluirlo, el proxy queda
 *      "congelado" para siempre. Ese es el principal riesgo de UUPS.
 */
contract BoxUUPSV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
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

    function version() external pure virtual returns (string memory) {
        return "V1";
    }

    /// @dev Gatea el upgrade: solo el owner puede reemplazar la implementación.
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
