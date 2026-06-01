// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.24;

contract PayableContractV2 {
    function sendEther() public payable {}

    function withdrawEther(uint256 amount_) public {
        // recipient (cartera que recibe el ether) + call + valor ether + datos
        (bool success, ) = msg.sender.call{value: amount_}("");
        require(success, "Transaction failed");
    }
}
