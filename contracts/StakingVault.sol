// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/*====== Vesta Protocol Interfaces ======*/
import "./interfaces/vesta-protocol/IVestaParams.sol";

contract StakingVault is Ownable {
    using SafeMath for uint256;

    /*====== Errors ======*/
    error StakingVault__TargetICRNotValid();
    error StakingVault__PermittedSwingNotValid();
    error StakingVault__VestaAddressesNotInitialized();

    /*====== State Variables ======*/

    uint256 private targetICR;
    uint256 private permittedSwing;

    address private immutable collToken;
    address private yieldVaultAddress;

    /*====== Vesta Protocol Addresses ======*/
    address hintHelpers;
    address borrowerOperations;
    address vestaParams;
    address troveManager;
    address priceFeed;
    address sortedTroves;

    bool private vestaProtolAddressesInitialized;

    /*====== Events ======*/
    event TargetICRUpdated(uint256 newTargetICR);
    event PermittedSwingUpdated(uint256 newPermittedSwing);
    event VSTAddressesInitialized(
        address hintHelpers,
        address borrowerOperations,
        address vestaParams,
        address troveManager,
        address priceFeed,
        address sortedTroves
    );

    /*====== Modifier ======*/
    modifier vstAddressesInitialized() {
        if (vestaProtolAddressesInitialized == false) {
            revert StakingVault__VestaAddressesNotInitialized();
        }
        _;
    }

    constructor(
        address _collToken,
        address _yieldVaultAddress,
        uint256 _targetICR,
        uint256 _permittedSwing
    ) {
        collToken = _collToken;
        yieldVaultAddress = _yieldVaultAddress;

        targetICR = _targetICR;

        permittedSwing = _permittedSwing;
    }

    /*====== Setup Functions ======*/

    function initializeVSTAddresses(
        address _hintHelpers,
        address _borrowerOperations,
        address _vestaParams,
        address _troveManager,
        address _priceFeed,
        address _sortedTroves
    ) external onlyOwner {
        hintHelpers = _hintHelpers;
        borrowerOperations = _borrowerOperations;
        vestaParams = _vestaParams;
        troveManager = _troveManager;
        priceFeed = _priceFeed;
        sortedTroves = _sortedTroves;

        vestaProtolAddressesInitialized = true;

        emit VSTAddressesInitialized(
            hintHelpers,
            borrowerOperations,
            vestaParams,
            troveManager,
            priceFeed,
            sortedTroves
        );
    }

    function setTargetICR(
        uint256 _targetICR
    ) external vstAddressesInitialized onlyOwner {
        _isTargetICRValid(_targetICR);

        targetICR = _targetICR;

        emit TargetICRUpdated(targetICR);
    }

    function setPermittedSwing(
        uint256 _permittedSwing
    ) external vstAddressesInitialized onlyOwner {
        _isPermittedSwingValid(_permittedSwing);

        permittedSwing = _permittedSwing;

        emit PermittedSwingUpdated(permittedSwing);
    }

    /*====== Internal Functions ======*/

    function _isTargetICRValid(uint256 _newTargetICR) internal view {
        uint256 _minICR = _newTargetICR.sub(permittedSwing);
        bool _isValid = _minICR >= IVestaParameters(vestaParams).MCR(collToken);

        if (!_isValid) {
            revert StakingVault__TargetICRNotValid();
        }
    }

    function _isPermittedSwingValid(uint256 _newPermittedSwing) internal view {
        uint256 _minICR = targetICR.sub(_newPermittedSwing);
        bool _isValid = _minICR >= IVestaParameters(vestaParams).MCR(collToken);

        if (!_isValid) {
            revert StakingVault__PermittedSwingNotValid();
        }
    }

    /*====== Pure / View Functions ======*/

    function getTargetICR() external view returns (uint256) {
        return targetICR;
    }

    function getPermittedSwing() external view returns (uint256) {
        return permittedSwing;
    }

    function getCollTokenAddress() external view returns (address) {
        return collToken;
    }

    function getYieldVaultAddress() external view returns (address) {
        return yieldVaultAddress;
    }
}
