// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {BoxV1} from "../src/BoxV1.sol";
import {BoxV2} from "../src/BoxV2.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

/**
 * @dev Beacon: muchos proxies apuntan a UN beacon que guarda la implementación.
 *      Se actualiza el beacon UNA vez y TODOS los proxies pasan a la nueva
 *      versión a la vez. Ideal para fábricas de muchas instancias iguales.
 */
contract BeaconTest is Test {
    UpgradeableBeacon internal beacon;
    BoxV1 internal box1; // proxy 1
    BoxV1 internal box2; // proxy 2
    address internal owner = makeAddr("owner");

    uint256 internal constant BOX1_VALUE = 10;
    uint256 internal constant BOX2_VALUE = 20;

    function setUp() public {
        BoxV1 impl = new BoxV1();
        beacon = new UpgradeableBeacon(address(impl), owner);

        box1 = BoxV1(
            address(
                new BeaconProxy(
                    address(beacon),
                    abi.encodeCall(BoxV1.initialize, (BOX1_VALUE))
                )
            )
        );
        box2 = BoxV1(
            address(
                new BeaconProxy(
                    address(beacon),
                    abi.encodeCall(BoxV1.initialize, (BOX2_VALUE))
                )
            )
        );
    }

    function testTwoProxiesShareBeacon() public view {
        assertEq(box1.value(), BOX1_VALUE);
        assertEq(box2.value(), BOX2_VALUE);
        assertEq(box1.version(), "V1");
        assertEq(box2.version(), "V1");
    }

    function testUpgradeBeaconUpgradesAllProxies() public {
        BoxV2 implV2 = new BoxV2();

        // UN solo upgrade del beacon -> los dos proxies pasan a V2.
        vm.prank(owner);
        beacon.upgradeTo(address(implV2));

        assertEq(BoxV2(address(box1)).version(), "V2");
        assertEq(BoxV2(address(box2)).version(), "V2");

        // Cada proxy conserva su propio estado.
        assertEq(BoxV2(address(box1)).value(), BOX1_VALUE);
        assertEq(BoxV2(address(box2)).value(), BOX2_VALUE);

        BoxV2(address(box1)).increment();
        assertEq(BoxV2(address(box1)).value(), BOX1_VALUE + 1);
    }

    function testOnlyOwnerCanUpgradeBeacon() public {
        BoxV2 implV2 = new BoxV2();

        vm.prank(makeAddr("attacker"));
        vm.expectRevert();
        beacon.upgradeTo(address(implV2));
    }
}
