// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title BoxUUPSV2
 * @dev Nueva versión UUPS. Vuelve a incluir `_authorizeUpgrade` (si se omitiera,
 *      el proxy ya no podría volver a actualizarse). `value` queda en el mismo
 *      slot que en V1; lo nuevo es la función `increment`.
 */
contract BoxUUPSV2 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
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

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
