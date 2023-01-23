// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IVestaParameters {
    function MCR(address _collateral) external view returns (uint256);

    function BORROWING_FEE_FLOOR(
        address _collateral
    ) external view returns (uint256);
}
