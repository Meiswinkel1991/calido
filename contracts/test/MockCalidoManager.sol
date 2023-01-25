// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract MockCalidoManager {
    function sendTokensFallback() external {}

    function activateVault(address trove) external payable {
        (bool sent, ) = trove.call{value: msg.value}(
            abi.encodeWithSignature("activateVault()")
        );

        require(sent);
    }
}
