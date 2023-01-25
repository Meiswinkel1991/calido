// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ITrove {
    function activateVault() external payable;

    function depositETH() external payable;

    function withdrawETH(uint256 _amount) external;
}
