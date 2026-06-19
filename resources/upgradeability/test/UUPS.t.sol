// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {BoxUUPSV1} from "../src/uups/BoxUUPSV1.sol";
import {BoxUUPSV2} from "../src/uups/BoxUUPSV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @dev UUPS: el proxy es un ERC1967Proxy "mínimo" y la lógica de upgrade vive en
 *      la implementación. Se actualiza llamando `upgradeToAndCall` en el proxy.
 */
contract UUPSTest is Test {
    BoxUUPSV1 internal box; // el proxy, tipado como V1
    address internal proxy;

    uint256 internal constant INITIAL_VALUE = 42;
    uint256 internal constant STORED_VALUE = 100;

    function setUp() public {
        BoxUUPSV1 impl = new BoxUUPSV1();
        bytes memory initData = abi.encodeCall(
            BoxUUPSV1.initialize,
            (INITIAL_VALUE)
        );
        // El estado vive en el proxy; la implementación solo aporta el código.
        proxy = address(new ERC1967Proxy(address(impl), initData));
        box = BoxUUPSV1(proxy);
    }

    function testInitialState() public view {
        assertEq(box.value(), INITIAL_VALUE);
        assertEq(box.version(), "V1");
    }

    function testUpgradePreservesStateAndAddsLogic() public {
        box.store(STORED_VALUE);
        assertEq(box.value(), STORED_VALUE);

        // Upgrade a V2 (en UUPS va por la implementación, vía upgradeToAndCall).
        BoxUUPSV2 implV2 = new BoxUUPSV2();
        box.upgradeToAndCall(address(implV2), "");

        BoxUUPSV2 boxV2 = BoxUUPSV2(proxy);
        assertEq(boxV2.value(), STORED_VALUE); // el estado SOBREVIVE al upgrade
        assertEq(boxV2.version(), "V2"); // la lógica CAMBIÓ
        boxV2.increment(); // función NUEVA de V2
        assertEq(boxV2.value(), STORED_VALUE + 1);
    }

    function testOnlyOwnerCanUpgrade() public {
        BoxUUPSV2 implV2 = new BoxUUPSV2();

        // _authorizeUpgrade es onlyOwner -> un extraño no puede actualizar.
        vm.prank(makeAddr("attacker"));
        vm.expectRevert();
        box.upgradeToAndCall(address(implV2), "");
    }
}
