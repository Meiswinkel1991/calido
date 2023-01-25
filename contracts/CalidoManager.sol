// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./interfaces/vesta-protocol/ITroveManager.sol";
import "./interfaces/curve-protocol/IFactory.sol";
import "./interfaces/token/IERC20.sol";
import "./interfaces/protocol/ITrove.sol";

contract CalidoManager {
    error CalidoManager__NotTroveContract();

    /*====== State Variables ======*/
    address trove;
    address loopYieldTrove;

    address troveManagerVesta;
    address curveFactoryStableSwap;

    IERC20 VSTStableToken;
    IERC20 FRAXStableToken;

    /*====== Modifier ======*/
    modifier isTroveContract() {
        if (msg.sender != trove) {
            revert CalidoManager__NotTroveContract();
        }
        _;
    }

    constructor(
        address _trove,
        address _loopYieldTrove,
        address _VSTStableToken,
        address _FRAXStableToken
    ) {
        trove = _trove;
        loopYieldTrove = _loopYieldTrove;

        VSTStableToken = IERC20(_VSTStableToken);
        FRAXStableToken = IERC20(_FRAXStableToken);
    }

    receive() external payable {}

    fallback() external payable {}

    /*====== Main Functions ======*/

    function stakeEther() external payable {
        uint256 _depositAmount = msg.value;

        if (_isTroveActive()) {
            ITrove(trove).depositETH{value: _depositAmount}();
        } else {
            ITrove(trove).activateVault{value: _depositAmount}();
        }
    }

    function sendTokensFallback() external isTroveContract {
        uint256 _balanceVST = VSTStableToken.balanceOf(address(this));

        // check for the change rate

        uint256 _dy = IFactory(curveFactoryStableSwap).get_dy(
            0,
            1,
            _balanceVST
        );

        uint256 _swappedFRAX = IFactory(curveFactoryStableSwap).exchange(
            0,
            1,
            _balanceVST,
            _dy
        );
    }

    function sendDebtTokensToTrove(
        uint256 _amountNeeded
    ) external isTroveContract returns (bool) {
        bool sent = IERC20(VSTStableToken).transfer(msg.sender, _amountNeeded);

        return sent;
    }

    function setAddresses(
        address _troveManagerVesta,
        address _curveFactoryStableSwap
    ) external {
        troveManagerVesta = _troveManagerVesta;
        curveFactoryStableSwap = _curveFactoryStableSwap;
    }

    /*====== Internal Functions ======*/

    function _isTroveActive() internal view returns (bool) {
        uint256 _troveStatus = ITroveManager(troveManagerVesta).getTroveStatus(
            address(0),
            trove
        );

        if (_troveStatus == 1) {
            return true;
        }

        return false;
    }

    function _swapVSTStableToFRAX() internal {}
}
