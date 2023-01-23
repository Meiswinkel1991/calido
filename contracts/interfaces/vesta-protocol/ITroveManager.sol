// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ITroveManager {
    enum Status {
        nonExistent,
        active,
        closedByOwner,
        closedByLiquidation,
        closedByRedemption
    }

    // Store the necessary data for a trove
    struct Trove {
        address asset;
        uint256 debt;
        uint256 coll;
        uint256 stake;
        Status status;
        uint128 arrayIndex;
    }

    function getCurrentICR(
        address _asset,
        address _borrower,
        uint256 _price
    ) external view returns (uint256);

    function getTroveStatus(
        address _asset,
        address _borrower
    ) external view returns (uint256);

    function getTroveOwnersCount(
        address _asset
    ) external view returns (uint256);

    function getTroveFromTroveOwnersArray(
        address _asset,
        uint256 _index
    ) external view returns (address);

    function getNominalICR(
        address _asset,
        address _borrower
    ) external view returns (uint256);

    function getEntireDebtAndColl(
        address _asset,
        address _borrower
    )
        external
        view
        returns (
            uint256 debt,
            uint256 coll,
            uint256 pendingVSTDebtReward,
            uint256 pendingAssetReward
        );
}
