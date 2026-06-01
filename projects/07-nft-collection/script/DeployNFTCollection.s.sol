// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {NFTCollection} from "../src/NFTCollection.sol";

contract DeployNFTCollection is Script {
    string name_ = "Solidity Portfolio";
    string symbol_ = "SP";
    uint256 totalSupply_ = 10;
    string baseURI_ = "ipfs://REEMPLAZAR_CON_CID_DE_LAS_URIS/";

    function run() external returns (NFTCollection) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        NFTCollection nftCollection = new NFTCollection(
            name_,
            symbol_,
            totalSupply_,
            baseURI_
        );
        vm.stopBroadcast();
        return nftCollection;
    }
}
