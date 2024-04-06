// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;


import {VirtualLP} from "src/V2MultiAsset/VirtualLP.sol";
import {MockToken} from "./mocks/MockToken.sol";
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

contract HandlerVirtual is VirtualLP {

    uint256 constant _AMOUNT_TO_CONVERT = 100000 * 1e18;
    uint256 constant _FUNDING_PHASE_DURATION = 604800; // 7 days

    uint256 public _fundingBalance;
    bool public _isActiveLP;
    bool public _bTokenCreated; 

    mapping(address portal => bool isRegistered) public _registeredPortals;
    mapping(address portal => mapping(address asset => address vault)) public _vaults;
    mapping(address portal => mapping(address asset => uint256 pid)) public _poolID;

    uint256 constant _MAX_UINT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    constructor(address _tokenAddress, uint256 _FUNDING_MIN_AMOUNT)
        VirtualLP(_tokenAddress, _AMOUNT_TO_CONVERT,_FUNDING_PHASE_DURATION, _FUNDING_MIN_AMOUNT) {}


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


    function _handler_activateLP() external {
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

    function _handler_increaseAllowanceVault(address _portal) public {
        /// @dev Get the asset of the Portal
        address asset = address(0x0003);

        /// @dev Allow spending of Assets by the associated Vault
        MockToken(asset).safeIncreaseAllowance(
            vaults[_portal][asset],
            MAX_UINT
        );
    }

    // function _handler_depositToYieldSource(
    //     address _asset,
    //     uint256 _amount
    // ) external {

    //     /// @dev Deposit tokens into Vault to receive Shares (WATER)
    //     /// @dev Approval of token spending is handled with a separate function to save gas
    //     uint256 depositShares = 20;

    //     /// @dev Stake the Vault Shares into the staking contract using the pool identifier (pid)
    //     /// @dev Approval of token spending is handled with a separate function to save gas
    //     ISingleStaking(SINGLE_STAKING).deposit(
    //         poolID[msg.sender][_asset],
    //         depositShares
    //     );
    // }

    function _handler_getBurnValuePSM(
        uint256 _amount
    ) public view returns (uint256 burnValue) {
        /// @dev Calculate the minimum burn value
        uint256 minValue = (_amount * 100) / FUNDING_MAX_RETURN_PERCENT;

        /// @dev Calculate the time based burn value
        uint256 accruedValue = (_amount *
            (block.timestamp - CREATION_TIME) *
            FUNDING_APR) / (100 * SECONDS_PER_YEAR);

        /// @dev Calculate the maximum and current burn value
        uint256 maxValue = _amount;
        uint256 currentValue = minValue + accruedValue;

        burnValue = (currentValue < maxValue) ? currentValue : maxValue;
    }

    function _handler_getBurnableBtokenAmount()
        public
        view
        returns (uint256 amountBurnable)
    {
        /// @dev Calculate the burn value of 1 full bToken in PSM
        /// @dev Add 1 WEI to handle rounding issue in the next step
        uint256 burnValueFullToken = _handler_getBurnValuePSM(1e18) + 1;

        /// @dev Calculate and return the amount of bTokens burnable
        /// @dev This will slightly underestimate because of the 1 WEI for reliability reasons
        amountBurnable = (fundingRewardPool * 1e18) / burnValueFullToken;
    }

    function _handler_burnBtokens(uint256 _amount, address hbToken, address psm) external {
        /// @dev Check that the burn amount is not zero
        if (_amount == 0) {
            revert InvalidAmount();
        }

        /// @dev Check that the burn amount is not larger than what can be redeemed
        uint256 burnable = _handler_getBurnableBtokenAmount();
        if (_amount > burnable) {
            revert InvalidAmount();
        }

        /// @dev Calculate how many PSM the user receives based on the burn amount
        uint256 amountToReceive = _handler_getBurnValuePSM(_amount);

        /// @dev Reduce the funding reward pool by the amount of PSM payable to the user
        fundingRewardPool -= amountToReceive;

        /// @dev Burn the bTokens from the user's balance
        MockToken(hbToken).burnFrom(msg.sender, _amount);

        /// @dev Transfer the PSM to the user
        MockToken(psm).transfer(msg.sender, amountToReceive);

        /// @dev Event that informs about burn amount and received PSM by the caller
        emit RewardsRedeemed(msg.sender, _amount, amountToReceive);
    }

    function _handler_convert(
        address _token,
        address _recipient,
        uint256 _minReceived,
        uint256 _deadline,
        address _psmToken
    ) external nonReentrant activeLP {
        /// @dev Check the validity of token and recipient addresses
        // if (_token == PSM_ADDRESS || _recipient == address(0)) {
        //     revert InvalidAddress();
        // }

        // /// @dev Prevent zero value
        // if (_minReceived == 0) {
        //     revert InvalidAmount();
        // }

        // /// @dev Check that the deadline has not expired
        // if (_deadline < block.timestamp) {
        //     revert DeadlineExpired();
        // }

        /// @dev Get the contract balance of the specified token
        uint256 contractBalance;
        if (_token == address(0)) {
            contractBalance = address(this).balance;
        } else {
            contractBalance = IERC20(_token).balanceOf(address(this));
        }

        /// @dev Check that enough output tokens are available for frontrun protection
        if (contractBalance < _minReceived) {
            revert InsufficientReceived();
        }

        /// @dev initialize helper variables
        uint256 maxRewards = MockToken(hbToken).totalSupply();
        uint256 newRewards = (AMOUNT_TO_CONVERT * FUNDING_REWARD_SHARE) / 100;

        /// @dev Check if rewards must be added, adjust reward pool accordingly
        if (fundingRewardPool + newRewards >= maxRewards) {
            fundingRewardPool = maxRewards;
        } else {
            fundingRewardPool += newRewards;
        }

        /// @dev transfer PSM to the LP
        MockToken(_psmToken).transferFrom(
            msg.sender,
            address(this),
            _AMOUNT_TO_CONVERT
        );

        /// @dev Transfer the output token from the contract to the recipient
        if (_token == address(0)) {
            (bool sent, ) = payable(_recipient).call{value: contractBalance}(
                ""
            );
            if (!sent) {
                revert FailedToSendNativeToken();
            }
        } else {
            MockToken(_token).safeTransfer(_recipient, contractBalance);
        }

        emit ConvertExecuted(_token, msg.sender, _recipient, contractBalance);
    }





}

