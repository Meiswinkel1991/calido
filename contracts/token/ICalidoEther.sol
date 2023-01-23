// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../interfaces/token/IERC20Metadata.sol";

interface ICalidoEther is IERC20Metadata {
    function mint(address to, uint256 amount) external;

    function burn(address account, uint256 amount) external;
}
