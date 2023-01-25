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

import "./interfaces/protocol/ICalidoManager.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Trove {
    using SafeMath for uint256;

    /*====== Errors ======*/
    error Trove__TroveIsActive();
    error Trove__TroveIsNotActive();
    error Trove__NoEtherBalance();
    error Trove__NonZeroAmount();
    error Trove__NotEnoughFunds();
    error Trove__NotCalidoManager();
    error Trove__NotEnoughCollateral();

    /*====== State Variables ====== */

    uint256 targetICR;
    uint256 normalRange;
    uint256 emergencyRange;

    address calidoManagerContract;

    /*====== Vesta Protocol Addresses ======*/
    address hintHelpers;
    address borrowerOperations;
    address vestaParams;
    address troveManager;
    address priceFeed;
    address sortedTroves;

    IERC20 VSTStableToken;

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

    modifier noActiveTrove() {
        uint256 _troveStatus = ITroveManager(troveManager).getTroveStatus(
            address(0),
            address(this)
        );

        if (_troveStatus == 1) {
            revert Trove__TroveIsActive();
        }
        _;
    }

    modifier activeTrove() {
        uint256 _troveStatus = ITroveManager(troveManager).getTroveStatus(
            address(0),
            address(this)
        );

        if (_troveStatus != 1) {
            revert Trove__TroveIsNotActive();
        }
        _;
    }

    /*====== Events ======*/
    event TroveActivated(uint256 coll);
    event TroveUpdated(uint256 coll, uint256 debt);

    constructor(uint256 _deviationCR, uint256 _targetICR) {
        normalRange = _deviationCR;
        targetICR = _targetICR;
    }

    receive() external payable {}

    fallback() external payable {}

    /**
     * @dev -activate the vault an initialize a vesta finance vault with an ICR of targetICR
     *
     */
    function activateVault() external payable noActiveTrove isCalidoManager {
        uint256 _balanceETH = msg.value;
        if (_balanceETH == 0) {
            revert Trove__NoEtherBalance();
        }

        _openNewTrove(_balanceETH);

        _transferStableTokensToManagerContract();

        emit TroveActivated(_balanceETH);
    }

    function depositETH()
        external
        payable
        nonZeroAmount
        activeTrove
        isCalidoManager
    {
        uint256 _amount = msg.value;

        _adjustTrove(_amount, true);
    }

    function withdrawETH(
        uint256 _amount
    ) external nonZeroTokenAmount(_amount) isCalidoManager {
        _adjustTrove(_amount, false);

        (bool sent, ) = msg.sender.call{value: _amount}("");

        require(sent);
    }

    function adjustTrove() public activeTrove isCalidoManager {
        _adjustTrove(0, true);
    }

    /*====== Setup Functions ======*/

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

    function setManagerContract(address _manager) external {
        //TODO: safe this function. Only once should be possible to call this function
        calidoManagerContract = _manager;
    }

    /*====== Internal ======*/

    function _openNewTrove(uint256 _coll) internal {
        uint256 _debt = _coll.mul(getAssetPrice()).div(targetICR);

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

    function _adjustTrove(uint256 _deltaColl, bool _increase) internal {
        (uint256 _debt, uint256 _coll, , ) = ITroveManager(troveManager)
            .getEntireDebtAndColl(address(0), address(this));

        uint256 _newColl = _increase
            ? _coll.add(_deltaColl)
            : _coll.sub(_deltaColl);

        uint256 _currentICR = _newColl.mul(getAssetPrice()).div(_debt);

        bool _paybackDebt = _currentICR < targetICR.sub(normalRange);

        uint256 _targetDebt = (_newColl).mul(getAssetPrice()).div(targetICR);
        bool _isDebtIncrease = _targetDebt >= _debt ? true : false;

        uint256 _deltaDebt;

        if (_paybackDebt) {
            _deltaDebt = _debt.sub(_targetDebt);

            bool _receive = ICalidoManager(calidoManagerContract)
                .sendDebtTokensToTrove(_deltaDebt);
            require(_receive);

            VSTStableToken.approve(borrowerOperations, _deltaDebt);
        } else {
            _deltaDebt = _isDebtIncrease ? _targetDebt.sub(_debt) : 0;
        }

        // Add collateral and adjust debt to reach the target price
        uint256 _newDebt = _isDebtIncrease
            ? _debt.add(_deltaDebt)
            : _debt.sub(_deltaDebt);

        (address _upperHint, address _lowerHint) = _calculateHints(
            (_coll.add(_deltaColl)),
            _newDebt
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

        emit TroveUpdated(_newColl, _newDebt);
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

    function _transferStableTokensToManagerContract() internal {
        uint256 _tokenBalance = VSTStableToken.balanceOf(address(this));
        if (_tokenBalance > 0) {
            bool _sent = VSTStableToken.transfer(
                calidoManagerContract,
                _tokenBalance
            );
            require(_sent);

            if (_isContract(calidoManagerContract)) {
                ICalidoManager(calidoManagerContract).sendTokensFallback();
            }
        }
    }

    function _isContract(
        address _addr
    ) internal view returns (bool isContract) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    /*====== Pure View Functions ======*/

    function getCurrentICRVault() public view returns (uint256) {
        uint256 _price = IPriceFeed(priceFeed).getExternalPrice(address(0));
        return
            ITroveManager(troveManager).getCurrentICR(
                address(0),
                address(this),
                _price
            );
    }

    function getAssetPrice() public view returns (uint256) {
        return IPriceFeed(priceFeed).getExternalPrice(address(0));
    }

    // function getAssetBalance() public view returns (uint256) {
    //     console.log(address(this).balance);
    //     return address(this).balance;
    // }
}
