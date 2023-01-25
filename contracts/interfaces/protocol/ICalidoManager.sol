// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ICalidoManager {
    function sendTokensFallback() external;

    function sendDebtTokensToTrove(
        uint256 _amountNeeded
    ) external returns (bool);
}
