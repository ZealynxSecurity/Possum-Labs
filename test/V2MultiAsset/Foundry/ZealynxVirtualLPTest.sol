// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {FoundrySetup} from "./FoundrySetup.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {IWater} from "src/V2MultiAsset/interfaces/IWater.sol";
import {ISingleStaking} from "src/V2MultiAsset/interfaces/ISingleStaking.sol";

contract ZealynxVirtualLPTest is FoundrySetup {

    // ============================================
    // ==             HELPER ACTIONS             ==
    // ============================================
    function _register(
        address testPortal,
        address testAsset,
        address testVault,
        uint256 testPid
    ) internal {
        // Precondition
        vm.prank(psmSender);
        virtualLP.registerPortal(
            testPortal, 
            testAsset, 
            testVault, 
            testPid
        );
    }

    function _prepareLP() internal {
        _create_bToken();
        _fundLP();
        _register(
            address(portal_USDC),
            _PRINCIPAL_TOKEN_ADDRESS_USDC,
            USDC_WATER,
            _POOL_ID_USDC
        );
        _register(
            address(portal_ETH),
            _PRINCIPAL_TOKEN_ADDRESS_ETH,
            WETH_WATER,
            _POOL_ID_WETH
        );
        _activateLP();
    }

    // create the bToken token
    function _create_bToken() internal {
        virtualLP.create_bToken();
    }

    // fund the Virtual LP
    function _fundLP() internal {
        vm.prank(psmSender);
        psm.approve(address(virtualLP), 1e55);
        vm.prank(psmSender);
        virtualLP.contributeFunding(_FUNDING_MIN_AMOUNT);
    }

    // activate the Virtual LP
    function _activateLP() internal {
        vm.warp(fundingPhase);
        virtualLP.activateLP();
    }

    // send USDC to LP when balance is required
    function helper_sendUSDCtoLP() internal {
        vm.prank(usdcSender);
        usdc.transfer(address(virtualLP), usdcSendAmount); // Send 1k USDC to LP
    }

    function _prepareYieldSourceUSDC(uint256 _amount) internal {
        _prepareLP();

        vm.prank(usdcSender);
        usdc.transfer(address(portal_USDC), _amount);

        vm.prank(address(portal_USDC));
        usdc.transfer(address(virtualLP), _amount);

        vm.prank(address(portal_USDC));
        usdc.approve(address(virtualLP), 1e55);
        vm.prank(address(portal_USDC));
        virtualLP.increaseAllowanceVault(address(portal_USDC));
        virtualLP.increaseAllowanceSingleStaking(address(portal_USDC));
        virtualLP.increaseAllowanceDualStaking();
    }

    function prepare_contribution() internal {
        uint256 _fundingAmount = 1e18;
        _create_bToken();

        vm.prank(Alice);
        psm.approve(address(virtualLP), 1e55);
        vm.prank(Alice);
        virtualLP.contributeFunding(_fundingAmount);
    }

    function prepare_convert() internal {
        vm.prank(Alice);
        prepare_contribution();

        // Precondition
        _fundLP();
        _activateLP();

        // Action
        helper_sendUSDCtoLP();
        vm.prank(psmSender);
        psm.approve(address(virtualLP), 1e55);
        vm.prank(psmSender);
    }

    // ============================================
    // ==          HELPER VERIFICATIONS          ==
    // ============================================
    function _assertPortalRegistered(
        address testPortal,
        address testAsset,
        address testVault,
        uint256 testPid
    ) internal {
        assertTrue(virtualLP.registeredPortals(testPortal) == true);
        assertTrue(virtualLP.vaults(testPortal, testAsset) == testVault);
        assertTrue(virtualLP.poolID(testPortal, testAsset) == testPid); 
    }

    // ============================================
    // ==            REGISTER PORTAL             ==
    // ============================================

    ///////////////////////////////////////////////
    ////////////////// UNIT TESTS /////////////////
    ///////////////////////////////////////////////

    function test_register_portal_usdc() public {
        address testPortal = address(portal_USDC);
        address testAsset = _PRINCIPAL_TOKEN_ADDRESS_USDC; 
        address testVault = address(USDC_WATER);
        uint256 testPid = _POOL_ID_USDC;

        // Action
        _register(
            testPortal, 
            testAsset, 
            testVault, 
            testPid
        );

        // Verification
        _assertPortalRegistered(
            testPortal, 
            testAsset, 
            testVault, 
            testPid
        );
    }

    function test_register_portal_eth() public {
        address testPortal = address(portal_ETH);
        address testAsset = _PRINCIPAL_TOKEN_ADDRESS_ETH; 
        address testVault = address(WETH_WATER);
        uint256 testPid = _POOL_ID_WETH;
        
        // Action
        _register(
            testPortal, 
            testAsset, 
            testVault, 
            testPid
        );

        // Verification
        _assertPortalRegistered(
            testPortal, 
            testAsset, 
            testVault, 
            testPid
        );    
    }
        
    function test_revert_register_portal_not_owner() public {
        address testPortal = address(portal_ETH);
        address testAsset = _PRINCIPAL_TOKEN_ADDRESS_ETH; 
        address testVault = address(WETH_WATER);
        uint256 testPid = _POOL_ID_WETH;

        // Precondition
        vm.prank(Alice);
        // Action
        vm.expectRevert(ErrorsLib.NotOwner.selector);
        virtualLP.registerPortal(
                testPortal, 
                testAsset, 
                testVault, 
                testPid
        );
    }

    // ============================================
    // ==              REMOVE OWNER              ==
    // ============================================

    ///////////////////////////////////////////////
    ////////////////// UNIT TESTS /////////////////
    ///////////////////////////////////////////////
    
    function test_address_changed_to_zero() public {
        // Precondition
        vm.warp(block.timestamp + OWNER_DURATION + 1);
        virtualLP.removeOwner();

        // Action
        vm.expectRevert(ErrorsLib.OwnerRevoked.selector);
        virtualLP.removeOwner();
    }

    function test_revert_remove_owner() public {
        // Precondition
        vm.warp(OWNER_DURATION - 10);
        address ownerBefore = virtualLP.owner.address;

        // Action
        vm.expectRevert(ErrorsLib.OwnerNotExpired.selector);
        virtualLP.removeOwner();
    }

    // ============================================
    // ==        DEPOSIT TO YIELD SOURCE         ==
    // ============================================

    ///////////////////////////////////////////////
    ////////////////// UNIT TESTS /////////////////
    ///////////////////////////////////////////////

    function test_deposit_to_yield_source() public {
        // Preconditions
        uint256 _amount = 1e7;
        _prepareYieldSourceUSDC(_amount);

        // Action
        vm.prank(address(portal_USDC));
        virtualLP.depositToYieldSource(address(usdc), _amount);
    }

    function test_only_registered_portal_deposit_to_yield_source() public {
        // Preconditions
        uint256 _amount = 1e7;
        _prepareYieldSourceUSDC(_amount);

        // Action
        vm.prank(Bob);
        vm.expectRevert(ErrorsLib.PortalNotRegistered.selector);
        virtualLP.depositToYieldSource(address(usdc), _amount);
    }

    ///////////////////////////////////////////////
    ////////////////// FUZZ TESTS /////////////////
    ///////////////////////////////////////////////
    
    // function test_fuzz_deposit_to_yield_source(uint256 _amount) public {
    //     // Preconditions
    //     vm.assume(_amount > 0);
    //     vm.assume(_amount < 1e18);

    //     _prepareYieldSourceUSDC(_amount);

    //     // Action
    //     vm.prank(address(portal_USDC));
    //     virtualLP.depositToYieldSource(address(usdc), _amount);

    //     // Check that stake was processed correctly in Vault and staking contract
    //     uint256 depositShares = IWater(USDC_WATER).convertToShares(_amount);
    //     uint256 stakedShares = ISingleStaking(SINGLE_STAKING).getUserAmount(
    //         _POOL_ID_USDC,
    //         address(virtualLP)
    //     );

    //     // Verification
    //     assertTrue(usdc.balanceOf(address(portal_USDC)) == 0);
    //     assertTrue(depositShares == stakedShares);
    // }

    // ============================================
    // ==       WITHDRAW FROM YIELD SOURCE       ==
    // ============================================

    ///////////////////////////////////////////////
    ////////////////// UNIT TESTS /////////////////
    ///////////////////////////////////////////////

    function test_only_registered_portal_withdraw_from_yield_source() public {
        // Preconditions
        uint256 _amount = 1e7;
        _prepareYieldSourceUSDC(_amount);
        vm.prank(address(portal_USDC));
        virtualLP.depositToYieldSource(address(usdc), _amount);

        vm.warp(block.timestamp + 100);
        // Action
        vm.prank(address(Bob));
        vm.expectRevert(ErrorsLib.PortalNotRegistered.selector);
        virtualLP.withdrawFromYieldSource(address(usdc), Alice, _amount);
    }

    ///////////////////////////////////////////////
    ////////////////// FUZZ TESTS /////////////////
    ///////////////////////////////////////////////

    // function test_withdraw_from_yield_source(uint256 _amount) public {
    //     // Preconditions
    //     vm.assume(_amount > 0);
    //     _prepareYieldSourceUSDC(_amount);
    //     vm.prank(address(portal_USDC));
    //     virtualLP.depositToYieldSource(address(usdc), _amount);


    //     uint256 balanceUser1Start = usdc.balanceOf(Alice);
    //     vm.warp(block.timestamp + 100);

    //     uint256 withdrawShares = IWater(USDC_WATER).convertToShares(_amount);
    //     uint256 grossReceived = IWater(USDC_WATER).convertToAssets(
    //         withdrawShares
    //     );
    //     uint256 denominator = IWater(USDC_WATER).DENOMINATOR();
    //     uint256 fees = (grossReceived * IWater(USDC_WATER).withdrawalFees()) /
    //         denominator;
    //     uint256 netReceived = grossReceived - fees;

    //     // Action
    //     vm.prank(address(portal_USDC));
    //     virtualLP.withdrawFromYieldSource(address(usdc), Alice, _amount);

    //     // Verification
    //     assertTrue(usdc.balanceOf(Alice) == balanceUser1Start + netReceived);
    // }

    // ============================================
    // ==              PSM CONVERTER             ==
    // ============================================

    //////////////// UNIT TESTS /////////////////

    function test_convert() public {
        prepare_convert();

        virtualLP.convert(
            _PRINCIPAL_TOKEN_ADDRESS_USDC,
            msg.sender,
            1,
            block.timestamp
        );
    }

    function test_revert_with_invalid_recipient_address() public {
        prepare_convert();

        // Action
        vm.expectRevert(ErrorsLib.InvalidAddress.selector);
        virtualLP.convert(_PRINCIPAL_TOKEN_ADDRESS_USDC, address(0), 100, block.timestamp + 1 days);
    }

    function test_revert_with_zero_min_amount() public {
        prepare_convert();

        // Action
        vm.expectRevert(ErrorsLib.InvalidAmount.selector);
        virtualLP.convert(WETH_ADDRESS, Alice, 0, block.timestamp + 1 days);
    }

    function test_reward_pool_adjustment() public {
        prepare_convert();

        uint256 initialRewardPool = virtualLP.fundingRewardPool();

        // Action
        virtualLP.convert(_PRINCIPAL_TOKEN_ADDRESS_USDC, Alice, 100, block.timestamp + 1 days);

        // Verification
        uint256 expectedNewReward = (_AMOUNT_TO_CONVERT * FUNDING_REWARD_SHARE) / 100;
        assertTrue(virtualLP.fundingRewardPool() == initialRewardPool + expectedNewReward);
    }

    function test_correct_token_transfer() public {
        prepare_convert();

        uint256 recipientBalanceBefore = weth.balanceOf(Alice);

        // Action
        virtualLP.convert(
            _PRINCIPAL_TOKEN_ADDRESS_USDC,
            msg.sender,
            1,
            block.timestamp
        );

        // Check the recipient received the tokens correctly
        uint256 recipientBalanceAfter = weth.balanceOf(Alice);

        assert(recipientBalanceAfter == recipientBalanceBefore + _AMOUNT_TO_CONVERT);
    }

    function test_revert_with_invalid_token_address() public {
        prepare_convert();

        // Action
        vm.expectRevert(ErrorsLib.InvalidAddress.selector);
        virtualLP.convert(PSM_ADDRESS, Alice, 100, block.timestamp + 1 days);
    }

    function test_revert_after_deadline() public {
        prepare_convert();

        vm.warp(block.timestamp + 2 days);

        // Action
        vm.expectRevert(ErrorsLib.InsufficientReceived.selector);
        virtualLP.convert(_PRINCIPAL_TOKEN_ADDRESS_USDC, Alice, 100, block.timestamp - 1 days);
    }

    function test_revert_insufficient_balance() public {
        prepare_convert();

        // Action
        virtualLP.convert(_PRINCIPAL_TOKEN_ADDRESS_USDC, Alice, 1e18, block.timestamp + 1 days);
    }
}