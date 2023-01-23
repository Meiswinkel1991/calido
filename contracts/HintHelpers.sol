// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "hardhat/console.sol";
import "./interfaces/vesta-protocol/ISortedTroves.sol";
import "./interfaces/vesta-protocol/ITroveManager.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @dev - This contract will not deploy on the mainnet. It is only required for testing!!!!
 */
contract HintHelpers {
    using SafeMath for uint256;

    uint256 internal constant NICR_PRECISION = 1e20;

    ITroveManager troveManager;
    ISortedTroves sortedTroves;

    constructor(address _troveManager, address _sortedTroves) {
        troveManager = ITroveManager(_troveManager);
        sortedTroves = ISortedTroves(_sortedTroves);
    }

    function getApproxHint(
        address _asset,
        uint256 _CR,
        uint256 _numTrials,
        uint256 _inputRandomSeed
    )
        external
        view
        returns (address hintAddress, uint256 diff, uint256 latestRandomSeed)
    {
        uint256 arrayLength = troveManager.getTroveOwnersCount(_asset);

        if (arrayLength == 0) {
            return (address(0), 0, _inputRandomSeed);
        }

        hintAddress = sortedTroves.getLast(_asset);
        diff = _getAbsoluteDifference(
            _CR,
            troveManager.getNominalICR(_asset, hintAddress)
        );
        latestRandomSeed = _inputRandomSeed;

        uint256 i = 1;

        while (i < _numTrials) {
            latestRandomSeed = uint256(
                keccak256(abi.encodePacked(latestRandomSeed))
            );

            uint256 arrayIndex = latestRandomSeed % arrayLength;
            address currentAddress = troveManager.getTroveFromTroveOwnersArray(
                _asset,
                arrayIndex
            );
            uint256 currentNICR = troveManager.getNominalICR(
                _asset,
                currentAddress
            );

            //check if abs(current - CR) > abs(closest - CR), and update closest if current is closer
            uint256 currentDiff = _getAbsoluteDifference(currentNICR, _CR);

            if (currentDiff < diff) {
                diff = currentDiff;
                hintAddress = currentAddress;
            }
            i++;
        }
    }

    function computeNominalCR(
        uint256 _coll,
        uint256 _debt
    ) external pure returns (uint256) {
        return _computeNominalCR(_coll, _debt);
    }

    function _getAbsoluteDifference(
        uint256 _a,
        uint256 _b
    ) internal pure returns (uint256) {
        return (_a >= _b) ? _a.sub(_b) : _b.sub(_a);
    }

    function _computeNominalCR(
        uint256 _coll,
        uint256 _debt
    ) internal pure returns (uint256) {
        if (_debt > 0) {
            return _coll.mul(NICR_PRECISION).div(_debt);
        }
        // Return the maximal value for uint256 if the Trove has a debt of 0. Represents "infinite" CR.
        else {
            // if (_debt == 0)
            return 2 ** 256 - 1;
        }
    }

    function computeCR(
        uint256 _coll,
        uint256 _debt,
        uint256 _price
    ) external pure returns (uint256) {
        if (_debt > 0) {
            uint256 newCollRatio = _coll.mul(_price).div(_debt);

            return newCollRatio;
        }
        // Return the maximal value for uint256 if the Trove has a debt of 0. Represents "infinite" CR.
        else {
            // if (_debt == 0)
            return type(uint256).max;
        }
    }
}
