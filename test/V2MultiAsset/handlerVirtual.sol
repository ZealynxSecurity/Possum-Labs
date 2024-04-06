// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;


import {VirtualLP} from "src/V2MultiAsset/VirtualLP.sol";
import{MockToken} from "./mocks/MockToken.sol";
import {esVKAToken} from "src/onchain/esVKAToken.sol";



// ============================================
// ==              CUSTOM ERRORS             ==
// ============================================
error InactiveLP();
error ActiveLP();
error NotOwner();
error PortalNotRegistered();
error OwnerNotExpired();
error InsufficientReceived();
error InvalidConstructor();
error InvalidAddress();
error InvalidAmount();
error DeadlineExpired();
error FailedToSendNativeToken();
error FundingPhaseOngoing();
error FundingInsufficient();
error TokenExists();
error TimeLockActive();
error NoProfit();
error OwnerRevoked();

contract handlerVirtual is VirtualLP {



    uint256 public _fundingBalance;
    bool public _isActiveLP;
    bool public _bTokenCreated; 

    mapping(address portal => bool isRegistered) public _registeredPortals;
    mapping(address portal => mapping(address asset => address vault)) public _vaults;
    mapping(address portal => mapping(address asset => uint256 pid)) public _poolID;

    uint256 constant _MAX_UINT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    constructor(address _tokenAddress, uint256 _AMOUNT_TO_CONVERT, uint256 _FUNDING_PHASE_DURATION, uint256 _FUNDING_MIN_AMOUNT)
        VirtualLP(_tokenAddress, _AMOUNT_TO_CONVERT,_FUNDING_PHASE_DURATION, _FUNDING_MIN_AMOUNT) {
        }


    function _contributeFunding(uint256 _amount, address psm, address hbToken) external {
        /// @dev Prevent zero amount transaction
        if (_amount == 0) {
            revert InvalidAmount();
        }

        uint256 mintableAmount = (_amount * FUNDING_MAX_RETURN_PERCENT) / 100;

        _fundingBalance += _amount;

       MockToken(psm).transferFrom(msg.sender, address(this), _amount);

        MockToken(hbToken).mint(msg.sender, mintableAmount);
    }


    function _activateLP() external {
        /// @dev Check that the funding phase is over and enough funding has been contributed
        if (block.timestamp < CREATION_TIME + FUNDING_PHASE_DURATION) {
            revert FundingPhaseOngoing();
        }
        if (_fundingBalance < FUNDING_MIN_AMOUNT) {
            revert FundingInsufficient();
        }

        /// @dev Activate the Virtual LP
        _isActiveLP = true;

        /// @dev Emit the activation event with the address of the contract and the funding balance
        emit LP_Activated(address(this), fundingBalance);
    }

    function _increaseAllowanceDualStaking(address _esVKA, address _dualS) public {
        esVKAToken(_esVKA).safeIncreaseAllowance(_esVKA, _dualS, _MAX_UINT );
    }


    function _increaseAllowanceSingleStaking(address _portal, uint256 _asset) public {
        /// @dev Get the asset of the Portal
        // address asset = IPortalV2MultiAsset(_portal).PRINCIPAL_TOKEN_ADDRESS();

        /// @dev Allow spending of Vault Shares of a Portal by the single staking contract
        MockToken(vaults[_portal][_asset]).safeIncreaseAllowance(
            SINGLE_STAKING,
            MAX_UINT
        );
    }













}

