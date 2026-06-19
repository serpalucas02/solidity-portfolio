// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {BoxV1} from "../src/BoxV1.sol";
import {BoxV2} from "../src/BoxV2.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @dev Transparent: la lógica de upgrade vive en el PROXY, manejada por un
 *      ProxyAdmin aparte. El admin no puede llamar funciones de la implementación
 *      (para evitar choques de selectores); los usuarios normales sí.
 *      En OZ v5 el TransparentUpgradeableProxy crea su propio ProxyAdmin.
 */
contract TransparentTest is Test {
    BoxV1 internal box; // el proxy, tipado como V1
    address internal proxy;
    ProxyAdmin internal admin;
    address internal owner = makeAddr("owner");

    uint256 internal constant INITIAL_VALUE = 42;
    uint256 internal constant STORED_VALUE = 100;

    // Slot ERC-1967 donde el proxy guarda la address del admin.
    // keccak256("eip1967.proxy.admin") - 1
    bytes32 internal constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function setUp() public {
        BoxV1 impl = new BoxV1();
        bytes memory initData = abi.encodeCall(BoxV1.initialize, (INITIAL_VALUE));

        // El constructor despliega el proxy Y un ProxyAdmin con owner = `owner`.
        proxy = address(
            new TransparentUpgradeableProxy(address(impl), owner, initData)
        );
        box = BoxV1(proxy);

        // Recupero la address del ProxyAdmin leyendo el slot ERC-1967.
        admin = ProxyAdmin(
            address(uint160(uint256(vm.load(proxy, ADMIN_SLOT))))
        );
    }

    function testInitialState() public view {
        assertEq(box.value(), INITIAL_VALUE);
        assertEq(box.version(), "V1");
    }

    function testUpgradeViaProxyAdmin() public {
        box.store(STORED_VALUE);

        BoxV2 implV2 = new BoxV2();
        // El upgrade va por el ProxyAdmin, y solo lo puede ordenar su owner.
        vm.prank(owner);
        admin.upgradeAndCall(
            ITransparentUpgradeableProxy(proxy),
            address(implV2),
            ""
        );

        BoxV2 boxV2 = BoxV2(proxy);
        assertEq(boxV2.value(), STORED_VALUE); // estado persiste
        assertEq(boxV2.version(), "V2"); // lógica nueva
        boxV2.increment();
        assertEq(boxV2.value(), STORED_VALUE + 1);
    }

    function testOnlyAdminOwnerCanUpgrade() public {
        BoxV2 implV2 = new BoxV2();

        vm.prank(makeAddr("attacker"));
        vm.expectRevert();
        admin.upgradeAndCall(
            ITransparentUpgradeableProxy(proxy),
            address(implV2),
            ""
        );
    }
}
