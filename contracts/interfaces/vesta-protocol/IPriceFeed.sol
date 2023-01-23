// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IPriceFeed {
    function getExternalPrice(address _token) external view returns (uint256);
}
