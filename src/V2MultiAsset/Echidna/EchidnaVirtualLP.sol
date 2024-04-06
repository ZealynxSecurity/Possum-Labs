// SPDX-License-Identifier: GPL-2.0-only
pragma solidity =0.8.19;

import "./EchidnaSetup.sol";

import {IWater} from "src/V2MultiAsset/interfaces/IWater.sol";
import {ISingleStaking} from "src/V2MultiAsset/interfaces/ISingleStaking.sol";

contract EchidnaVirtualLP is EchidnaSetup {

    constructor() payable {}

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
        hevm.prank(psmSender);
        try virtualLP.registerPortal(
            testPortal, 
            testAsset, 
            testVault, 
            testPid
        ) {
            // continue
        } catch {
            // Verification
            assert(false);
        }
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
        hevm.prank(psmSender);
        psm.approve(address(virtualLP), 1e55);
        hevm.prank(psmSender);
        try virtualLP.contributeFunding(_FUNDING_MIN_AMOUNT) {
            // continue
        } catch {
            // Verification
            assert(false);
        }
    }

    // activate the Virtual LP
    function _activateLP() internal {
        hevm.warp(fundingPhase);
        virtualLP.activateLP();
    }

    // send USDC to LP when balance is required
    function helper_sendUSDCtoLP() internal {
        hevm.prank(usdcSender);
        usdc.transfer(address(virtualLP), usdcSendAmount); // Send 1k USDC to LP
    }

    function _prepareYieldSourceUSDC(uint256 _amount) internal {
        _prepareLP();

        hevm.prank(usdcSender);
        usdc.transfer(address(portal_USDC), _amount);

        hevm.prank(address(portal_USDC));
        usdc.transfer(address(virtualLP), _amount);

        hevm.prank(address(portal_USDC));
        usdc.approve(address(virtualLP), 1e55);
        hevm.prank(address(portal_USDC));
        virtualLP.increaseAllowanceVault(address(portal_USDC));
        virtualLP.increaseAllowanceSingleStaking(address(portal_USDC));
        virtualLP.increaseAllowanceDualStaking();
    }

    function prepare_contribution() internal {
        uint256 _fundingAmount = 1e18;
        _create_bToken();

        hevm.prank(USER1);
        psm.approve(address(virtualLP), 1e55);
        hevm.prank(USER1);
        try virtualLP.contributeFunding(_fundingAmount) {
            // continue
        } catch {
            // Verification
            assert(false);
        }
    }

    function prepare_convert() internal {
        hevm.prank(USER1);
        prepare_contribution();

        // Precondition
        _fundLP();
        _activateLP();

        // Action
        helper_sendUSDCtoLP();
        hevm.prank(psmSender);
        psm.approve(address(virtualLP), 1e55);
        hevm.prank(psmSender);
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
        assert(virtualLP.registeredPortals(testPortal) == true);
        assert(virtualLP.vaults(testPortal, testAsset) == testVault);
        assert(virtualLP.poolID(testPortal, testAsset) == testPid); 
    }

    // ============================================
    // ==            REGISTER PORTAL             ==
    // ============================================

    /////////////// UNIT TESTS ///////////////
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
        hevm.prank(USER1);
        // Action
        try virtualLP.registerPortal(
                testPortal, 
                testAsset, 
                testVault, 
                testPid
            )
        {
            assert(false);
        } catch {
            // Verification
            assert(true);
        }
    }

    // ============================================
    // ==              REMOVE OWNER              ==
    // ============================================

    /////////////// UNIT TESTS ///////////////
    function test_address_changed_to_zero() public {
        // Precondition
        hevm.warp(block.timestamp + OWNER_DURATION + 1);
        virtualLP.removeOwner();

        // Action
        try virtualLP.removeOwner() {
            assert(false);
        } catch {
            // Verification
            assert(true);
        }
    }

    function test_revert_remove_owner() public {
        // Precondition
        hevm.warp(OWNER_DURATION - 10);
        address ownerBefore = virtualLP.owner.address;
        Debugger.log("Owner address before:", ownerBefore);

        // Action
        try virtualLP.removeOwner() {
            assert(false);
        } catch {
            // Verification
            assert(true);
        }
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
        hevm.prank(address(portal_USDC));
        try virtualLP.depositToYieldSource(address(usdc), _amount) {
            assert(true);
        } catch {
            assert(false);
        }
    }

    function test_only_registered_portal_deposit_to_yield_source() public {
        // Preconditions
        uint256 _amount = 1e7;
        _prepareYieldSourceUSDC(_amount);

        // Action
        hevm.prank(USER2);
        try virtualLP.depositToYieldSource(address(usdc), _amount) {
            assert(false);
        } catch {
            assert(true);
        }
    }

    ///////////////////////////////////////////////
    ////////////////// FUZZ TESTS /////////////////
    ///////////////////////////////////////////////
    
    function test_fuzz_deposit_to_yield_source(uint256 _amount) public {
        // Preconditions
        require(_amount > 0);
        _prepareYieldSourceUSDC(_amount);

        // Action
        hevm.prank(address(portal_USDC));
        virtualLP.depositToYieldSource(address(usdc), _amount);

        // Check that stake was processed correctly in Vault and staking contract
        uint256 depositShares = IWater(USDC_WATER).convertToShares(_amount);
        uint256 stakedShares = ISingleStaking(SINGLE_STAKING).getUserAmount(
            _POOL_ID_USDC,
            address(virtualLP)
        );

        // Verification
        assert(usdc.balanceOf(address(portal_USDC)) == 0);
        assert(depositShares == stakedShares);
    }

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
        hevm.prank(address(portal_USDC));
        virtualLP.depositToYieldSource(address(usdc), _amount);

        hevm.warp(block.timestamp + 100);
        // Action
        hevm.prank(address(USER2));
        try virtualLP.withdrawFromYieldSource(address(usdc), USER1, _amount) {
            assert(false);
        } catch {
            assert(true);
        }
    }

    function test_withdraw_from_yield_source(uint256 _amount) public {
        // Preconditions
        require(_amount > 0);
        _prepareYieldSourceUSDC(_amount);
        hevm.prank(address(portal_USDC));
        virtualLP.depositToYieldSource(address(usdc), _amount);


        uint256 balanceUser1Start = usdc.balanceOf(USER1);
        hevm.warp(block.timestamp + 100);

        uint256 withdrawShares = IWater(USDC_WATER).convertToShares(_amount);
        uint256 grossReceived = IWater(USDC_WATER).convertToAssets(
            withdrawShares
        );
        uint256 denominator = IWater(USDC_WATER).DENOMINATOR();
        uint256 fees = (grossReceived * IWater(USDC_WATER).withdrawalFees()) /
            denominator;
        uint256 netReceived = grossReceived - fees;

        // Action
        hevm.prank(address(portal_USDC));
        virtualLP.withdrawFromYieldSource(address(usdc), USER1, _amount);

        // Verification
        assert(usdc.balanceOf(USER1) == balanceUser1Start + netReceived);
    }

    // ============================================
    // ==              PSM CONVERTER             ==
    // ============================================

    //////////////// UNIT TESTS /////////////////

    function test_convert() public {
        prepare_convert();

        try virtualLP.convert(
            _PRINCIPAL_TOKEN_ADDRESS_USDC,
            msg.sender,
            1,
            block.timestamp
        ) {
            assert(true);
        } catch {
            assert(false);
        }
    }

    function test_revert_with_invalid_recipient_address() public {
        prepare_convert();

        // Action
        try virtualLP.convert(_PRINCIPAL_TOKEN_ADDRESS_USDC, address(0), 100, block.timestamp + 1 days) {
            assert(false);
        } catch {
            // Verification
            assert(true);
        }
    }

    function test_revert_with_zero_min_amount() public {
        prepare_convert();

        // Action
        try virtualLP.convert(WETH_ADDRESS, USER1, 0, block.timestamp + 1 days) {
            assert(false);
        } catch {
            // Verification
            assert(true);
        }
    }

    function test_reward_pool_adjustment() public {
        prepare_convert();

        uint256 initialRewardPool = virtualLP.fundingRewardPool();

        // Action
        virtualLP.convert(_PRINCIPAL_TOKEN_ADDRESS_USDC, USER1, 100, block.timestamp + 1 days);

        // Verification
        uint256 expectedNewReward = (_AMOUNT_TO_CONVERT * FUNDING_REWARD_SHARE) / 100;
        assert(virtualLP.fundingRewardPool() == initialRewardPool + expectedNewReward);
    }

    function test_correct_token_transfer() public {
        prepare_convert();

        uint256 recipientBalanceBefore = weth.balanceOf(USER1);

        // Action
        virtualLP.convert(
            _PRINCIPAL_TOKEN_ADDRESS_USDC,
            msg.sender,
            1,
            block.timestamp
        );

        // Check the recipient received the tokens correctly
        uint256 recipientBalanceAfter = weth.balanceOf(USER1);

        assert(recipientBalanceAfter == recipientBalanceBefore + _AMOUNT_TO_CONVERT);
    }

    function test_revert_with_invalid_token_address() public {
        prepare_convert();

        // Action
        try virtualLP.convert(PSM_ADDRESS, USER1, 100, block.timestamp + 1 days) {
            assert(false);
        } catch {
            // Verification
            assert(true);
        }
    }

    function test_revert_after_deadline() public {
        prepare_convert();

        hevm.warp(block.timestamp + 2 days);

        // Action
        try virtualLP.convert(_PRINCIPAL_TOKEN_ADDRESS_USDC, USER1, 100, block.timestamp - 1 days) {
            assert(false);
        } catch {
            // Verification
            assert(true);
        }
    }

    function test_revert_insufficient_balance() public {
        prepare_convert();

        // Action
        try virtualLP.convert(_PRINCIPAL_TOKEN_ADDRESS_USDC, USER1, 1e18, block.timestamp + 1 days) {
            assert(false);
        } catch {
            // Verification
            assert(true);
        }
    }

    ///////////////////////////////////////////////
    ////////////////// FUZZ TESTS /////////////////
    ///////////////////////////////////////////////

    function test_fuzz_convert(uint256 _deadline) public {
        // Precondition
        prepare_convert();

        // Action
        try virtualLP.convert(_PRINCIPAL_TOKEN_ADDRESS_USDC, USER1, 100, block.timestamp + _deadline) {
            assert(true);
        } catch {
            // Verification
            // Fail in case it reverts
            assert(false);
        }
    }

    // ============================================
    // ==           CONTRIBUTE FUNDING           ==
    // ============================================

    ///////////////////////////////////////////////
    ////////////////// UNIT TESTS /////////////////
    ///////////////////////////////////////////////

    function test_contribute_funding() public {
        _create_bToken();

        uint256 _fundingAmount = 1e8;
        hevm.prank(USER1);
        psm.approve(address(virtualLP), 1e55);
        Debugger.log("Mira balance: ", address(virtualLP).balance);
        hevm.prank(USER1);
        try virtualLP.contributeFunding(_fundingAmount) {
            // continue
        } catch {
            // Verification
            assert(false);
        }

        assert(psm.balanceOf(USER1) == psmAmount - _fundingAmount);
    }

    function test_revert_contribute_funding() public {
        _create_bToken();

        uint256 _fundingAmount = 1e8;
        hevm.prank(USER1);
        psm.approve(address(virtualLP), 1e55);
        
        hevm.prank(psmSender);
        // Action
        try virtualLP.contributeFunding(_fundingAmount) {
            assert(false);
        } catch {
            // Verification
            assert(true);
        }
    }

    function test_revert_contribute_zero_funding() public {
        _create_bToken();

        uint256 _fundingAmount = 0;
        hevm.prank(USER1);
        psm.approve(address(virtualLP), 1e55);
        
        hevm.prank(USER1);
        // Action
        try virtualLP.contributeFunding(_fundingAmount) {
            assert(false);
        } catch {
            // Verification
            assert(true);
        }
    }

    function test_contract_balance_after_contribute_funding() public {
        _create_bToken();

        uint256 beforeBalance = psm.balanceOf(address(virtualLP));

        uint256 _fundingAmount = 1e8;
        hevm.prank(USER1);
        psm.approve(address(virtualLP), 1e55);
        hevm.prank(USER1);
        virtualLP.contributeFunding(_fundingAmount);

        uint256 afterBalance = beforeBalance + _fundingAmount;

        // Verification
        assert(psm.balanceOf(address(virtualLP)) == afterBalance);
    }

    function test_funding_balance_increased() public {
        _create_bToken();

        uint256 existingFundingBalance = virtualLP.fundingBalance();
        uint256 _fundingAmount = 1e8;
        hevm.prank(USER1);
        psm.approve(address(virtualLP), 1e55);
        hevm.prank(USER1);
        virtualLP.contributeFunding(_fundingAmount);

        existingFundingBalance = existingFundingBalance + _fundingAmount;

        // Verification
        assert(virtualLP.fundingBalance() == existingFundingBalance);
    }

    function test_bToken_minted() public {
        _create_bToken();

        IERC20 bToken = IERC20(address(virtualLP.bToken()));
        uint256 _fundingAmount = 1e8;
        uint256 mintableAmount = (_fundingAmount * FUNDING_MAX_RETURN_PERCENT) / 100;

        hevm.prank(USER1);
        psm.approve(address(virtualLP), 1e55);
        hevm.prank(USER1);
        virtualLP.contributeFunding(_fundingAmount);

        assert(bToken.balanceOf(USER1) == mintableAmount);
    }

    ///////////////////////////////////////////////
    ////////////////// FUZZ TESTS /////////////////
    ///////////////////////////////////////////////

    function test_fuzz_contribute_funding(uint256 _fundingAmount) public {
        // Precondition
        require(_fundingAmount != 0);
        require(_fundingAmount < psmAmount);
        _create_bToken();

        IERC20 bToken = IERC20(address(virtualLP.bToken()));
        uint256 existingFundingBalance = virtualLP.fundingBalance();
        uint256 mintableAmount = (_fundingAmount * FUNDING_MAX_RETURN_PERCENT) / 100;
        uint256 beforeBalance = psm.balanceOf(address(virtualLP));

        // Action
        hevm.prank(USER1);
        psm.approve(address(virtualLP), 1e55);
        hevm.prank(USER1);
        try virtualLP.contributeFunding(_fundingAmount) {
            assert(true);
        } catch {
            // Verification
            assert(false);
        }

        existingFundingBalance = existingFundingBalance + _fundingAmount;
        uint256 afterBalance = beforeBalance + _fundingAmount;

        // Verification
        assert(virtualLP.fundingBalance() == existingFundingBalance);
        assert(bToken.balanceOf(USER1) == mintableAmount);
        assert(psm.balanceOf(address(virtualLP)) == afterBalance);
    }

    // ============================================
    // ==           WITHDRAW FUNDING           ==
    // ============================================

    ///////////////////////////////////////////////
    ////////////////// UNIT TESTS /////////////////
    ///////////////////////////////////////////////

    function test_withdraw_funding() public {
        // Precondition
        _create_bToken();

        uint256 _fundingAmount = 1e18 + 13;
        uint256 withdrawAmount = (_fundingAmount *
            FUNDING_MAX_RETURN_PERCENT) / 1000; // withdraw 10% of the funded amount

        hevm.prank(USER1);
        psm.approve(address(virtualLP), 1e55);
        hevm.prank(USER1);
        virtualLP.contributeFunding(_fundingAmount);

        uint256 beforeBalance = psm.balanceOf(USER1);
        IERC20 bToken = IERC20(address(virtualLP.bToken()));

        // Action
        hevm.prank(USER1);
        bToken.approve(address(virtualLP), 1e55);
        hevm.prank(USER1);
        virtualLP.withdrawFunding(withdrawAmount);

        // Verification
        assert(bToken.balanceOf(USER1) == 9 * _fundingAmount);
    }

    function test_revert_withdraw_zero_funding() public {
        _create_bToken();
        _fundLP();

        hevm.prank(USER1);
        try virtualLP.withdrawFunding(0) {
            assert(false);
        } catch {
            assert(true);
        }
    }

    function test_revert_withdraw_funding_lp_active() public {
        _create_bToken();
        _fundLP();

        hevm.prank(USER1);
        psm.approve(address(virtualLP), 1e55);
        hevm.prank(USER1);
        virtualLP.contributeFunding(1000);
        _activateLP();

        hevm.prank(USER1);
        try virtualLP.withdrawFunding(1000) {
            assert(false);
        } catch {
            assert(true);
        }
    }

    function test_contract_balance_after_withdraw_funding() public {
        // Precondition
        _create_bToken();        
        uint256 _fundingAmount = 1e18 + 13;
        uint256 withdrawAmount = (_fundingAmount *
            FUNDING_MAX_RETURN_PERCENT) / 1000; // withdraw 10% of the funded amount


        hevm.prank(USER1);
        psm.approve(address(virtualLP), 1e55);
        hevm.prank(USER1);
        virtualLP.contributeFunding(_fundingAmount);

        uint256 beforeBalance = psm.balanceOf(address(virtualLP));
        IERC20 bToken = IERC20(address(virtualLP.bToken()));

        // Action
        hevm.prank(USER1);
        bToken.approve(address(virtualLP), 1e55);
        hevm.prank(USER1);
        virtualLP.withdrawFunding(withdrawAmount);

        // Verification
        // +1 because of precision cutoff, the contract gains 1 WEI    }
        assert(psm.balanceOf(address(virtualLP)) == (9 * _fundingAmount) / 10 + 1);
    }

    function test_funding_balance_decreased() public {
        // Precondition
        _create_bToken();
        uint256 _fundingAmount = 1e18 + 13;
        uint256 withdrawAmount = (_fundingAmount *
            FUNDING_MAX_RETURN_PERCENT) / 1000; // withdraw 10% of the funded amount

        uint256 existingFundingBalance = virtualLP.fundingBalance();
        hevm.prank(USER1);
        psm.approve(address(virtualLP), 1e55);
        hevm.prank(USER1);
        virtualLP.contributeFunding(_fundingAmount);

        IERC20 bToken = IERC20(address(virtualLP.bToken()));

        // Action
        hevm.prank(USER1);
        bToken.approve(address(virtualLP), 1e55);
        hevm.prank(USER1);
        virtualLP.withdrawFunding(withdrawAmount);

        existingFundingBalance = existingFundingBalance - _fundingAmount;

        // Verification
        assert(
            psm.balanceOf(USER1) == psmAmount - (9 * _fundingAmount) / 10 - 1
        ); // -1 because of precision cutoff, USER1 loses 1 WEI
    }

    function test_bToken_burned() public {
        // Precondition
        _create_bToken();
        uint256 _fundingAmount = 1e18 + 13;
        uint256 withdrawAmount = (_fundingAmount *
            FUNDING_MAX_RETURN_PERCENT) / 1000; // withdraw 10% of the funded amount

        hevm.prank(USER1);
        psm.approve(address(virtualLP), 1e55);
        hevm.prank(USER1);
        virtualLP.contributeFunding(_fundingAmount);

        IERC20 bToken = IERC20(address(virtualLP.bToken()));
        uint256 beforeBalance = bToken.balanceOf(USER1);

        // Action
        hevm.prank(USER1);
        bToken.approve(address(virtualLP), 1e55);
        hevm.prank(USER1);
        virtualLP.withdrawFunding(withdrawAmount);

        // Verification
        assert(bToken.balanceOf(USER1) == beforeBalance - withdrawAmount);
    }

    ///////////////////////////////////////////////
    ////////////////// FUZZ TESTS /////////////////
    ///////////////////////////////////////////////

    function test_fuzz_withdraw_funding(uint256 _fundingAmount) public {
        // Precondition
        _create_bToken();
        require(_fundingAmount != 0);
        require(_fundingAmount < psmAmount);

        uint256 withdrawAmount = (_fundingAmount *
            FUNDING_MAX_RETURN_PERCENT) / 1000; // withdraw 10% of the funded amount

        // Action
        hevm.prank(USER1);
        psm.approve(address(virtualLP), 1e55);
        hevm.prank(USER1);
        virtualLP.contributeFunding(_fundingAmount);

        IERC20 bToken = IERC20(address(virtualLP.bToken()));

        // Action
        hevm.prank(USER1);
        bToken.approve(address(virtualLP), 1e55);
        hevm.prank(USER1);
        virtualLP.withdrawFunding(withdrawAmount);

        // Verification
        assert(bToken.balanceOf(USER1) == 9 * _fundingAmount);
    }

    // ============================================
    // ==          GET BURN VALUE PSM            ==
    // ============================================

    ///////////////////////////////////////////////
    ////////////////// UNIT TESTS /////////////////
    ///////////////////////////////////////////////

    function test_revert_get_burn_value_psm_inactive_lp() public {
        uint256 _amount = 1e18;
        _create_bToken();
        _fundLP();

        // Action
        hevm.warp(block.timestamp + 1 days);
        try virtualLP.getBurnValuePSM(_amount) {
            assert(false);
        } catch {
            // Verification
            assert(true);
        }
    }

    ///////////////////////////////////////////////
    ////////////////// FUZZ TESTS /////////////////
    ///////////////////////////////////////////////

    function test_fuzz_get_burn_value_psm(uint256 _amount) public {
        // Precondition
        require(_amount != 0);
        uint256 creationTime = block.timestamp;
        _create_bToken();
        _fundLP();
        _activateLP();

        // Fast forward time
        hevm.warp(hundredYearsLater);
        // Calculate expected burn value after warping
        uint256 burnValueAfterWarp = virtualLP.getBurnValuePSM(_amount);

        // Expected minValue
        uint256 expectedMinValue = (_amount * 100) / FUNDING_MAX_RETURN_PERCENT;

        // Expected accruedValue (for a large warp, this will be significant)
        uint256 expectedAccruedValue = (_amount *
            (block.timestamp - creationTime) * FUNDING_APR) / (100 * SECONDS_PER_YEAR);

        // Calculate expectedCurrentValue
        uint256 expectedCurrentValue = expectedMinValue + expectedAccruedValue;
        
        // Calculate the maximum and current burn value
        uint256 expectedBurnValue = (expectedCurrentValue < _amount) ? expectedCurrentValue : _amount;

        // Assert that the burn value after warping matches the capped or calculated expectedBurnValue
        assert(burnValueAfterWarp == expectedBurnValue); // "Burn value after time warp does not match expected calculation.");
    }

    // ============================================
    // ==             BURN B TOKENS              ==
    // ============================================

    ///////////////////////////////////////////////
    ////////////////// UNIT TESTS /////////////////
    ///////////////////////////////////////////////

    function test_revert_burn_zero_b_tokens() public {
        // Precondition
        uint256 _amount = 0;
        prepare_convert();
        virtualLP.convert(
            _PRINCIPAL_TOKEN_ADDRESS_USDC,
            msg.sender,
            1,
            block.timestamp
        );

        hevm.prank(USER1);

        IERC20 bToken = IERC20(address(virtualLP.bToken()));
        uint256 beforeBalance = bToken.balanceOf(USER1);

        uint256 burnable = virtualLP.getBurnableBtokenAmount();
        Debugger.log("Burnable: ", burnable);

        // Action
        hevm.prank(USER1);
        bToken.approve(address(virtualLP), 1e55);
        hevm.prank(USER1);
        try virtualLP.burnBtokens(_amount) {
            assert(false);
        } catch {
            assert(true);
        }
    }

    ///////////////////////////////////////////////
    ////////////////// FUZZ TESTS /////////////////
    ///////////////////////////////////////////////

    function test_fuzz_burn_b_tokens(uint256 _amount) public {
        // Precondition
        require(_amount != 0);
        require(_amount < 1e18);
        uint256 withdrawAmount = (_amount *
            FUNDING_MAX_RETURN_PERCENT) / 1000;

        prepare_convert();
        virtualLP.convert(
            _PRINCIPAL_TOKEN_ADDRESS_USDC,
            msg.sender,
            1,
            block.timestamp
        );

        hevm.prank(USER1);

        IERC20 bToken = IERC20(address(virtualLP.bToken()));
        uint256 beforeBalance = bToken.balanceOf(USER1);

        uint256 burnable = virtualLP.getBurnableBtokenAmount();
        Debugger.log("Burnable: ", burnable);

        // Action
        hevm.prank(USER1);
        bToken.approve(address(virtualLP), 1e55);
        hevm.prank(USER1);
        Debugger.log("Amount to Burn : ", _amount);
        try virtualLP.burnBtokens(_amount) {
            // continue
        } catch {
            assert(false);
        }

        // Verification
        assert(bToken.balanceOf(USER1) == beforeBalance - withdrawAmount);
    }
}
