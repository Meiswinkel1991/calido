// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface IFactory {
    // get_dy(i: int128, j: int128, _dx: uint256)→ uint256: view

    function get_dy(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256);

    // exchange(i: int128, j: int128, _dx: uint256, _min_dy: uint256)→ uint256

    function exchange(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _min_dy
    ) external returns (uint256);
}
