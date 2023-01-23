// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "hardhat/console.sol";

import "./interfaces/vesta-protocol/IBorrowerOperations.sol";
import "./interfaces/vesta-protocol/IVestaParams.sol";
import "./interfaces/vesta-protocol/IHintHelpers.sol";
import "./interfaces/vesta-protocol/ITroveManager.sol";
import "./interfaces/vesta-protocol/IPriceFeed.sol";
import "./interfaces/vesta-protocol/ISortedTroves.sol";
import "./interfaces/token/IERC20.sol";

import "./token/ICalidoEther.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Trove {
    using SafeMath for uint256;

    /*====== Errors ======*/
    error Trove__NonZeroAmount();
    error Trove__NotEnoughFunds();
    error Trove__NotCalidoManager();
    error Trove__NotEnoughCollateral();

    /*====== State Variables ====== */

    uint256 totalStakedETH;

    uint256 targetICR;
    uint256 deviationCR;

    address calidoManagerContract;

    /*====== Vesta Protocol Addresses ======*/
    address hintHelpers;
    address borrowerOperations;
    address vestaParams;
    address troveManager;
    address priceFeed;
    address sortedTroves;

    IERC20 VSTStableToken;
    ICalidoEther calidoEther;

    /*====== Modifier ======*/
    modifier nonZeroAmount() {
        if (msg.value == 0) {
            revert Trove__NonZeroAmount();
        }
        _;
    }

    modifier nonZeroTokenAmount(uint256 _amount) {
        if (_amount == 0) {
            revert Trove__NonZeroAmount();
        }
        _;
    }

    modifier isCalidoManager() {
        if (msg.sender != calidoManagerContract) {
            revert Trove__NotCalidoManager();
        }
        _;
    }

    constructor(
        uint256 _deviationCR,
        uint256 _targetICR,
        address _stakingToken
    ) {
        deviationCR = _deviationCR;
        targetICR = _targetICR;
        calidoEther = ICalidoEther(_stakingToken);
    }

    receive() external payable {}

    fallback() external payable {}

    function depositETH() external payable nonZeroAmount {
        uint256 _amount = msg.value;

        calidoEther.mint(msg.sender, _amount);
    }

    function withdrawETH(uint256 _amount) external nonZeroTokenAmount(_amount) {
        if (_amount > address(this).balance) {
            //TODO: withdraw collateral from vesta vault and adjust trove
        }

        (bool sent, ) = msg.sender.call{value: _amount}("");

        require(sent);
    }

    function addCollateral(uint256 _coll) external {
        uint256 _balanceETH = address(this).balance;

        if (_coll > _balanceETH) {
            revert Trove__NotEnoughFunds();
        }

        uint256 _troveStatus = ITroveManager(troveManager).getTroveStatus(
            address(0),
            address(this)
        );

        if (_troveStatus != 1) {
            _openNewTrove(_coll);
        } else {
            _addCollateralToActiveTrove(_coll);
        }

        uint256 _tokenBalance = VSTStableToken.balanceOf(address(this));
        if (_tokenBalance > 0) {
            bool _sent = VSTStableToken.transfer(msg.sender, _tokenBalance);
            require(_sent);
        }
    }

    function withdrawCollateral(uint256 _amount) external {
        if (_amount > address(this).balance) {
            uint256 _withdrawAmount = _amount.sub(address(this).balance);

            (
                uint256 _stableTokensRequired,
                bool _increase
            ) = _calculateTokenRequiredTokens(_withdrawAmount);

            adjustTrove(_withdrawAmount, _stableTokensRequired, _increase);
        }
    }

    function adjustTrove(
        uint256 _withdrawColl,
        uint256 _deltaTokens,
        bool _increase
    ) public {}

    function setVestaProtocolAddresses(
        address _troveManager,
        address _hintHelpers,
        address _vestaParams,
        address _borrowerOperations,
        address _priceFeed,
        address _sortedTroves,
        address _VSTStableToken
    ) external {
        troveManager = _troveManager;
        hintHelpers = _hintHelpers;
        vestaParams = _vestaParams;
        borrowerOperations = _borrowerOperations;
        priceFeed = _priceFeed;
        sortedTroves = _sortedTroves;

        VSTStableToken = IERC20(_VSTStableToken);
    }

    /*====== Internal ======*/

    function _openNewTrove(uint256 _coll) internal {
        uint256 _price = IPriceFeed(priceFeed).getExternalPrice(address(0));

        uint256 _debt = _coll.mul(_price).div(targetICR);

        (address _upperHint, address _lowerHint) = _calculateHints(
            _coll,
            _debt
        );

        uint256 _maxBorrowingFee = IVestaParameters(vestaParams)
            .BORROWING_FEE_FLOOR(address(0));

        IBorrowerOperations(borrowerOperations).openTrove{value: _coll}(
            address(0),
            0,
            _maxBorrowingFee,
            _debt,
            _upperHint,
            _lowerHint
        );
    }

    function _addCollateralToActiveTrove(uint256 _deltaColl) internal {
        (uint256 _debt, uint256 _coll, , ) = ITroveManager(troveManager)
            .getEntireDebtAndColl(address(0), address(this));

        // Add collateral and adjust debt to reach the target price
        uint256 _price = IPriceFeed(priceFeed).getExternalPrice(address(0));
        uint256 _targetDebt = (_coll.add(_deltaColl)).mul(_price).div(
            targetICR
        );

        bool _isDebtIncrease = _targetDebt >= _debt ? true : false;
        uint256 _deltaDebt = _targetDebt >= _debt
            ? _targetDebt.sub(_debt)
            : _debt.sub(_targetDebt);

        (address _upperHint, address _lowerHint) = _calculateHints(
            (_coll.add(_deltaColl)),
            _targetDebt
        );

        uint256 _maxBorrowingFee = IVestaParameters(vestaParams)
            .BORROWING_FEE_FLOOR(address(0));

        IBorrowerOperations(borrowerOperations).adjustTrove{value: _deltaColl}(
            address(0),
            0,
            _maxBorrowingFee,
            0,
            _deltaDebt,
            _isDebtIncrease,
            _upperHint,
            _lowerHint
        );
    }

    function _calculateHints(
        uint256 _newColl,
        uint256 _newDebt
    ) internal view returns (address, address) {
        uint256 _NICR = IHintHelpers(hintHelpers).computeNominalCR(
            _newColl,
            _newDebt
        );

        uint256 _numTroves = ISortedTroves(sortedTroves).getSize(address(0));

        (address _aproxHint, , ) = IHintHelpers(hintHelpers).getApproxHint(
            address(0),
            _NICR,
            _numTroves,
            42
        );

        (address _upperHint, address _lowerHint) = ISortedTroves(sortedTroves)
            .findInsertPosition(address(0), _NICR, _aproxHint, _aproxHint);

        return (_upperHint, _lowerHint);
    }

    function _calculateTokenRequiredTokens(
        uint256 _colWithdraw
    ) internal view returns (uint256 _amount, bool _increase) {
        uint256 _price = IPriceFeed(priceFeed).getExternalPrice(address(0));

        (uint256 _debt, uint256 _coll, , ) = ITroveManager(troveManager)
            .getEntireDebtAndColl(address(0), address(this));

        if (_coll < _colWithdraw) {
            revert Trove__NotEnoughCollateral();
        }

        uint256 _newColl = _coll.sub(_colWithdraw);

        uint256 _cr = IHintHelpers(hintHelpers).computeCR(
            _newColl,
            _debt,
            _price
        );

        if (_cr < targetICR.sub(deviationCR)) {
            _amount = (_newColl.mul(_price).div(targetICR)).sub(_debt);
            _increase = false;
        }
        if (_cr > targetICR.add(deviationCR)) {
            _amount = _debt.sub(_newColl.mul(_price).div(targetICR));
            _increase = true;
        }
    }

    /*====== Pure View Functions ======*/

    function getCurrentICRVault() external view returns (uint256) {
        uint256 _price = IPriceFeed(priceFeed).getExternalPrice(address(0));
        return
            ITroveManager(troveManager).getCurrentICR(
                address(0),
                address(this),
                _price
            );
    }
}
