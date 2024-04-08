// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {PortalV2MultiAsset} from "src/V2MultiAsset/PortalV2MultiAsset.sol";
import {MintBurnToken} from "src/V2MultiAsset/MintBurnToken.sol";
import {VirtualLP} from "src/V2MultiAsset/VirtualLP.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {EventsLib} from "../libraries/EventsLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWater} from "src/V2MultiAsset/interfaces/IWater.sol";
import {ISingleStaking} from "src/V2MultiAsset/interfaces/ISingleStaking.sol";
import {IDualStaking} from "src/V2MultiAsset/interfaces/IDualStaking.sol";
import {IPortalV2MultiAsset} from "src/V2MultiAsset/interfaces/IPortalV2MultiAsset.sol";
import {FoundryLogic} from "./FoundryLogic.sol";

contract ZealynxPortalV2MultiAssetTest is FoundryLogic {

    // ============================================
    // ==                  STAKE                 ==
    // ============================================

    function testFuzzingStakeUSDC(uint256 _amountStake) public {
        _prepareLP();

        // Set up approvals on LP for USDC
        virtualLP.increaseAllowanceDualStaking();
        virtualLP.increaseAllowanceSingleStaking(address(portal_USDC));
        virtualLP.increaseAllowanceVault(address(portal_USDC));

        deal(address(usdc), Alice, 1e10);
        uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);

        vm.assume(_amountStake > 0 && _amountStake <= aliceInitialUSDCBalance);

        // Approval and Stake
        vm.startPrank(Alice);
        usdc.approve(address(portal_USDC), _amountStake);
        portal_USDC.stake(_amountStake);
        vm.stopPrank();

        uint256 aliceFinalUSDCBalance = usdc.balanceOf(Alice);

        // Verifications
        assertEq(aliceInitialUSDCBalance - _amountStake, aliceFinalUSDCBalance, "Alice's balance after staking is incorrect.");
        assertEq(portal_USDC.totalPrincipalStaked(), _amountStake, "The total principal staked does not match the stake amount.");
    }

    function testFuzzingStakeETH(uint256 _amountStake) public {
        _prepareLP();

        virtualLP.increaseAllowanceDualStaking();
        virtualLP.increaseAllowanceSingleStaking(address(portal_ETH));
        virtualLP.increaseAllowanceVault(address(portal_ETH));

        deal(address(weth), Alice, 1e10);
        uint256 balanceBefore = Alice.balance;
        vm.assume(_amountStake > 0 && _amountStake <= balanceBefore);

        // Approval and Stake
        vm.startPrank(Alice);
        portal_ETH.stake{value: _amountStake}(_amountStake);

        vm.stopPrank();

        uint256 aliceFinalETHBalance =  Alice.balance;

        // Verifications
        assertEq(balanceBefore - _amountStake, aliceFinalETHBalance, "Alice's balance after staking is incorrect.");
        assertEq(portal_ETH.totalPrincipalStaked(), _amountStake, "The total principal staked does not match the stake amount.");
    }

    function testFuzz_Revert_stake_PortalNotRegistered(uint256 _amountStake) public {
        _create_bToken();
        _fundLP();
        _activateLP();

        deal(address(usdc), Alice, 1e10);
        uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);

        vm.assume(_amountStake > 0 && _amountStake <= aliceInitialUSDCBalance);

        vm.startPrank(Alice);
        
        // Approve the fuzzed amount for the portal_USDC contract
        usdc.approve(address(portal_USDC), _amountStake);

        // Expect the transaction to be reverted due to the Portal not being registered
        vm.expectRevert(ErrorsLib.PortalNotRegistered.selector);
        portal_USDC.stake(_amountStake);

        vm.stopPrank();
    }

    function testFuzz_Revert_stake_Zero(uint256 _amountStake) public {
        _prepareLP();

        deal(address(usdc), Alice, 1e10); // Ensure Alice has enough USDC
        uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);

        // Assume _amountStake is valid and not zero
        vm.assume(_amountStake > 0 && _amountStake <= aliceInitialUSDCBalance);

        vm.startPrank(Alice);
        
        // Approve the fuzzed amount for the portal_USDC contract
        usdc.approve(address(portal_USDC), _amountStake);

        // Attempting to stake 0 should revert with the error InvalidAmount
        vm.expectRevert(ErrorsLib.InvalidAmount.selector);
        portal_USDC.stake(0);

        vm.stopPrank();
    }

    function testFuzz_Revert_stake_Ether(uint256 _amountStake) public {
        _prepareLP();

        deal(address(usdc), Alice, 1e10); // Ensure Alice has enough USDC
        uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);

        // Assume _amountStake is valid and not zero
        vm.assume(_amountStake > 0 && _amountStake <= aliceInitialUSDCBalance);

        vm.startPrank(Alice);
        
        // Approve the fuzzed amount for the portal_USDC contract
        usdc.approve(address(portal_USDC), _amountStake);

        vm.expectRevert(ErrorsLib.NativeTokenNotAllowed.selector);
        portal_USDC.stake{value: _amountStake}(_amountStake); // Sending a fixed amount of ether

        vm.stopPrank();
    }

    function testFuzz_Revert_stake_0_InvalidAmount(uint256 _amountStake) public {
        _prepareLP();
        helper_setApprovalsInLP_ETH();

        deal(address(weth), Alice, 1e10); // Ensure Alice has enough USDC
        uint256 aliceInitialETHBalance = Alice.balance;

        // Assume _amountStake is valid and not zero
        vm.assume(_amountStake > 0 && _amountStake <= aliceInitialETHBalance);

        vm.startPrank(Alice);

        vm.expectRevert(ErrorsLib.InvalidAmount.selector);
        portal_ETH.stake{value: 0}(_amountStake); // Sending a fixed amount of ether

        vm.stopPrank();
    }

    // ============================================
    // ==                 UNSTAKE                ==
    // ============================================

    function testUnstakeUSDC(uint256 _amountStake, uint256 timePassed) public {
        vm.assume(timePassed != 0);
        vm.assume(timePassed < 10_000 days);

        _prepareLP();
        helper_setApprovalsInLP_USDC();

        uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
        uint256 minOperationalAmount = 1e4; // Example of a minimum operational amount considering fees
        vm.assume(_amountStake >= minOperationalAmount && _amountStake <= aliceInitialUSDCBalance);

        vm.startPrank(Alice);
        helper_Stake(Alice, _amountStake);
        vm.stopPrank();

        // UNSTAKE
        uint256 balanceBefore = usdc.balanceOf(Alice);
        uint256 withdrawShares = IWater(USDC_WATER).convertToShares(_amountStake);
        uint256 grossReceived = IWater(USDC_WATER).convertToAssets(withdrawShares);
        uint256 denominator = IWater(USDC_WATER).DENOMINATOR();
        uint256 fees = (grossReceived * IWater(USDC_WATER).withdrawalFees()) / denominator;
        uint256 netReceived = grossReceived - fees;

        vm.warp(block.timestamp + timePassed);

        vm.prank(Alice);
        portal_USDC.unstake(_amountStake);

        uint256 balanceAfter = usdc.balanceOf(Alice);

        assertEq(balanceBefore, usdcAmount - _amountStake);
        assertEq(balanceAfter, balanceBefore + netReceived);
        assertTrue(balanceAfter <= usdcAmount);
    }


    function testUnstakeETH(uint256 _amountStake, uint256 timePassed) public {
        _prepareLP();
        helper_setApprovalsInLP_ETH();

        uint256 balanceBefore2 = Alice.balance;
        uint256 minOperationalAmount = 1e4; 
        vm.assume(_amountStake >= minOperationalAmount && _amountStake <= balanceBefore2);
        
        vm.startPrank(Alice);
        portal_ETH.stake{value: _amountStake}(_amountStake);
        vm.stopPrank();

        uint256 aliceFinalETHBalance = Alice.balance;

        // Verifications
        assertEq(balanceBefore2 - _amountStake, aliceFinalETHBalance, "Alice's balance after stake is incorrect.");
        assertEq(portal_ETH.totalPrincipalStaked(), _amountStake, "The total principal staked does not match the stake amount.");

        // UNSTAKE
        uint256 balanceBefore = Alice.balance;
        uint256 withdrawShares = IWater(WETH_WATER).convertToShares(_amountStake);
        uint256 grossReceived = IWater(WETH_WATER).convertToAssets(withdrawShares);
        uint256 denominator = IWater(WETH_WATER).DENOMINATOR();
        uint256 fees = (grossReceived * IWater(WETH_WATER).withdrawalFees()) / denominator;
        uint256 netReceived = grossReceived - fees;

        vm.warp(block.timestamp + timePassed);

        vm.prank(Alice);
        portal_ETH.unstake(_amountStake);

        uint256 balanceAfter = Alice.balance;

        assertEq(balanceBefore, 1e18 - _amountStake);
        assertEq(balanceAfter, balanceBefore + netReceived);
        assertTrue(balanceAfter <= 1e18);
    }

    // ============================================
    // ==            MINT NFT POSITION           ==
    // ============================================

    function testMintNFTposition(uint256 _amountStake, uint256 _amountAccount) public {
        portal_USDC.create_portalNFT();
        // STAKE //
        _prepareLP();
        helper_setApprovalsInLP_USDC();

        uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
        uint256 minOperationalAmount = 1e4; 
        vm.assume(_amountStake >= minOperationalAmount && _amountStake <= aliceInitialUSDCBalance);
        vm.assume(_amountAccount >= minOperationalAmount && _amountAccount <= aliceInitialUSDCBalance && _amountAccount != _amountStake);

        vm.startPrank(Alice);
        helper_Stake(Alice, _amountStake);
        vm.stopPrank();

        (
            ,
            uint256 lastMaxLockDurationBefore,
            uint256 stakeBalanceBefore,
            ,
            uint256 peBalanceBefore,
            ,

        ) = portal_USDC.getUpdateAccount(Alice, 0, true);

        vm.prank(Alice);
        portal_USDC.mintNFTposition(Karen);

        (
            ,
            uint256 lastMaxLockDurationAfter,
            uint256 stakeBalanceAfter,
            ,
            uint256 peBalanceAfter,
            ,

        ) = portal_USDC.getUpdateAccount(Alice, _amountAccount, true);

        assertTrue(lastMaxLockDurationBefore > 0);
        assertTrue(stakeBalanceBefore > 0);
        assertTrue(peBalanceBefore > 0);
        assertEq(lastMaxLockDurationAfter, lastMaxLockDurationBefore);
        assertEq(stakeBalanceAfter, _amountAccount);
        assertEq(peBalanceAfter, _amountAccount);

        (
            uint256 nftMintTime,
            uint256 nftLastMaxLockDuration,
            uint256 nftStakedBalance,
            uint256 nftPortalEnergy
        ) = portal_USDC.portalNFT().accounts(1);

        assertTrue(address(portal_USDC.portalNFT()) != address(0));
        assertEq(nftMintTime, block.timestamp);
        assertEq(nftLastMaxLockDuration, portal_USDC.maxLockDuration());
        assertEq(nftStakedBalance, stakeBalanceBefore);
        assertEq(nftPortalEnergy, peBalanceBefore);
    }

    function testMintNFTPositionFixedAccountAmount(uint256 _amountStake) public {
        portal_USDC.create_portalNFT(); 
        // STAKE //
        _prepareLP();
        helper_setApprovalsInLP_USDC();

        uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
        uint256 minOperationalAmount = 1e4;
        vm.assume(_amountStake >= minOperationalAmount && _amountStake <= aliceInitialUSDCBalance);

        vm.startPrank(Alice);
        helper_Stake(Alice, _amountStake);
        vm.stopPrank();

        (
            ,
            uint256 lastMaxLockDurationBefore,
            uint256 stakeBalanceBefore,
            ,
            uint256 peBalanceBefore,
            ,

        ) = portal_USDC.getUpdateAccount(Alice, 0, true);

        vm.prank(Alice);
        portal_USDC.mintNFTposition(Karen);

        (
            ,
            uint256 lastMaxLockDurationAfter,
            uint256 stakeBalanceAfter,
            ,
            uint256 peBalanceAfter,
            ,

        ) = portal_USDC.getUpdateAccount(Alice, 0, true);

        assertTrue(lastMaxLockDurationBefore > 0);
        assertTrue(stakeBalanceBefore > 0);
        assertTrue(peBalanceBefore > 0);
        assertEq(lastMaxLockDurationAfter, lastMaxLockDurationBefore);
        assertEq(stakeBalanceAfter, 0);
        assertEq(peBalanceAfter, 0);

        (
            uint256 nftMintTime,
            uint256 nftLastMaxLockDuration,
            uint256 nftStakedBalance,
            uint256 nftPortalEnergy
        ) = portal_USDC.portalNFT().accounts(1);

        assertTrue(address(portal_USDC.portalNFT()) != address(0));
        assertEq(nftMintTime, block.timestamp);
        assertEq(nftLastMaxLockDuration, portal_USDC.maxLockDuration());
        assertEq(nftStakedBalance, stakeBalanceBefore);
        assertEq(nftPortalEnergy, peBalanceBefore);
    }

    function test_EmptyAccount_mintNFTposition(uint256 _amountStake) public {
        portal_USDC.create_portalNFT();
        // STAKE //
        _prepareLP();
        helper_setApprovalsInLP_USDC();

        uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
        uint256 minOperationalAmount = 1e4; 
        vm.assume(_amountStake >= minOperationalAmount && _amountStake <= aliceInitialUSDCBalance);

        vm.startPrank(Alice);
        helper_Stake(Alice, _amountStake);
        vm.stopPrank();

        (
            ,
            uint256 lastMaxLockDurationBefore,
            uint256 stakeBalanceBefore,
            ,
            uint256 peBalanceBefore,
            ,

        ) = portal_USDC.getUpdateAccount(Alice, 0, true);

        vm.prank(Karen);
        vm.expectRevert(ErrorsLib.EmptyAccount.selector);
        portal_USDC.mintNFTposition(Karen);

    }

    // ============================================
    // ==          REDEEM NFT POSITION           ==
    // ============================================

    function testRedeemNFTPosition(uint256 fuzzAmount) public {
        testMintNFTPositionFixedAccountAmount(fuzzAmount);
        (
            ,
            ,
            uint256 stakeBalanceBefore,
            ,
            uint256 peBalanceBefore,
            ,

        ) = portal_USDC.getUpdateAccount(Karen, 0, true);

        assertEq(stakeBalanceBefore, 0);
        assertEq(peBalanceBefore, 0);

        vm.startPrank(Karen);
        portal_USDC.redeemNFTposition(1);

        (
            ,
            ,
            ,
            uint256 stakeBalanceAfter,
            ,
            uint256 peBalanceAfter,

        ) = portal_USDC.getUpdateAccount(Karen, 0, true);

        assertTrue(stakeBalanceAfter > 0);
        assertTrue(peBalanceAfter > 0);
    }

    function testRevertRedeemNFTposition(uint256 fuzzAmount) public {
        testMintNFTPositionFixedAccountAmount(fuzzAmount);
        (
            ,
            ,
            uint256 stakeBalanceBefore,
            ,
            uint256 peBalanceBefore,
            ,

        ) = portal_USDC.getUpdateAccount(Karen, 0, true);

        assertEq(stakeBalanceBefore, 0);
        assertEq(peBalanceBefore, 0);

        vm.startPrank(Karen);
        portal_USDC.redeemNFTposition(1);

        (
            ,
            ,
            uint256 stakeBalanceAfter,
            ,
            uint256 peBalanceAfter,
            ,

        ) = portal_USDC.getUpdateAccount(Karen, 0, true);

        assertTrue(stakeBalanceAfter > 0);
        assertTrue(peBalanceAfter > 0);
        vm.expectRevert();
        portal_USDC.redeemNFTposition(1);

    }


//////////////////
// buyPortalEnergy
//////////////////

    function testBuyPortalEnergy(uint256 _amountInputPSM) public { // @audit-ok => FV
        _prepareLP();

        uint256 portalEnergy;
        (, , , , portalEnergy, , ) = portal_USDC.getUpdateAccount(
            Alice,
            0,
            true
        );
        uint256 minOperationalAmount = 1e4; 
        uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
        vm.assume(_amountInputPSM >= minOperationalAmount && _amountInputPSM <= aliceInitialUSDCBalance);

        vm.startPrank(Alice);
        psm.approve(address(portal_USDC), 1e55);
        portal_USDC.buyPortalEnergy(Alice, _amountInputPSM, 1, block.timestamp);
        vm.stopPrank();

        (, , , , portalEnergy, , ) = portal_USDC.getUpdateAccount(
            Alice,
            0,
            true
        );

        uint256 reserve1 = _TARGET_CONSTANT_USDC / _FUNDING_MIN_AMOUNT;
        uint256 netPSMinput = (_amountInputPSM * 99) / 100;
        uint256 result = (netPSMinput * reserve1) /
            (netPSMinput + _FUNDING_MIN_AMOUNT);

        assertEq(portalEnergy, result);
    }

    function testRevert_buyPortalEnergy(uint256 fuzzAmount, uint256 _amountInputPSM) public {
        _prepareLP();

        uint256 minOperationalAmount = 1e4; 
        uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
        vm.assume(fuzzAmount >= minOperationalAmount && fuzzAmount <= aliceInitialUSDCBalance);
        vm.assume(_amountInputPSM < fuzzAmount && _amountInputPSM != 0);
        
        // amount 0
        vm.startPrank(Alice);
        vm.expectRevert(ErrorsLib.InvalidAmount.selector);
        portal_USDC.buyPortalEnergy(Alice, 0, 1, block.timestamp);

        // minReceived 0
        vm.expectRevert(ErrorsLib.InvalidAmount.selector);
        portal_USDC.buyPortalEnergy(Alice, 1e18, 0, block.timestamp);

        // recipient address(0)
        vm.expectRevert(ErrorsLib.InvalidAddress.selector);
        portal_USDC.buyPortalEnergy(address(0), 1e18, 1, block.timestamp);

        // received amount < minReceived
        vm.expectRevert(ErrorsLib.InsufficientReceived.selector);
        portal_USDC.buyPortalEnergy(Alice, _amountInputPSM, fuzzAmount, block.timestamp);
    }




//////////////////////////////////////////////////////
            //////////////////
            //     UNIT     //
            //////////////////
    
    function test_Correct_Stake() public {
        uint256 amount = 1e7;
        // First Step (prepareSystem)
        _prepareLP();

        // Second step (setApprovalsInLP_USDC )
        virtualLP.increaseAllowanceDualStaking();
        virtualLP.increaseAllowanceSingleStaking(address(portal_USDC));
        virtualLP.increaseAllowanceVault(address(portal_USDC));

        uint256 balanceBefore = usdc.balanceOf(Alice);

        vm.startPrank(Alice);
        usdc.approve(address(portal_USDC), 1e55);
        console2.log("PRINCIPAL_TOKEN_ADDRESS",(portal_USDC.PRINCIPAL_TOKEN_ADDRESS()));
        portal_USDC.stake(amount);
        vm.stopPrank();

        uint256 balanceAfter = usdc.balanceOf(Alice);

        assertEq(balanceBefore - amount, balanceAfter);
        assertEq(portal_USDC.totalPrincipalStaked(), amount);
    }
    
    // function test_No_Success_uinti_unstake_USDC() public { // @audit-ok
    //     uint256 amount = 1e7;
    //     _prepareLP();
    //     helper_setApprovalsInLP_USDC();

    //      uint256 balanceBefore2 = usdc.balanceOf(Alice);

    //     vm.startPrank(Alice);
    //     usdc.approve(address(portal_USDC), 1e55);
    //     console2.log("PRINCIPAL_TOKEN_ADDRESS",(portal_USDC.PRINCIPAL_TOKEN_ADDRESS()));
    //     portal_USDC.stake(amount);
    //     vm.stopPrank();

    //     uint256 balanceAfter2 = usdc.balanceOf(Alice);

    //     assertEq(balanceBefore2 - amount, balanceAfter2);
    //     assertEq(portal_USDC.totalPrincipalStaked(), amount);


    //     vm.warp(block.timestamp + 100);

    //     (, , uint256 stakedBalance, , )= portal_USDC.getAccountDetails(Alice);
    //     // amount > user stake balance
    //     vm.startPrank(psmSender);
    //     psm.approve(address(portal_USDC), 1e55);
    //     portal_USDC.buyPortalEnergy(Alice, 1e18, 1, hundredYearsLater);
    //     vm.stopPrank();

    //     vm.startPrank(Alice);
    //     vm.expectRevert(ErrorsLib.InsufficientStakeBalance.selector);
    //     portal_USDC.unstake(stakedBalance + 1);

    //     vm.stopPrank();
    // }
    // function testSuccess2_getUpdateAccount() public {
    //     uint256 amount = 1e7;
    //     _prepareLP();
    //     helper_setApprovalsInLP_USDC();

    //     uint256 balanceBefore = usdc.balanceOf(Alice);

    //     vm.startPrank(Alice);
    //     usdc.approve(address(portal_USDC), 1e55);
    //     portal_USDC.stake(amount);
    //     vm.stopPrank();

    //     uint256 balanceAfter = usdc.balanceOf(Alice);

    //     assertEq(balanceBefore - amount, balanceAfter);
    //     assertEq(portal_USDC.totalPrincipalStaked(), amount);

    //     vm.startPrank(Alice);
    //     (
    //         uint256 lastUpdateTime,
    //         uint256 lastMaxLockDuration,
    //         uint256 stakedBalance,
    //         uint256 maxStakeDebt,
    //         uint256 portalEnergy,
    //         uint256 availableToWithdraw,
    //         uint256 portalEnergyTokensRequired
    //     ) = portal_USDC.getUpdateAccount(Alice, 1000, true);

    //     assertEq(lastUpdateTime, block.timestamp);
    //     assertEq(lastMaxLockDuration, portal_USDC.maxLockDuration());
    //     assertEq(stakedBalance, amount + 1000);
    //     assertEq(
    //         maxStakeDebt,
    //         (stakedBalance * lastMaxLockDuration * 1e18) /
    //             (SECONDS_PER_YEAR * portal_USDC.DECIMALS_ADJUSTMENT())
    //     );
    //     assertEq(portalEnergy, maxStakeDebt);
    //     assertEq(availableToWithdraw, amount + 1000);
    //     assertEq(portalEnergyTokensRequired, 0);

    //     vm.stopPrank();
    // }


  ////////////// HELPER FUNCTIONS /////////////

    function helper_Stake(address account, uint256 fuzzAmount) public {
        // STAKE
        uint256 initialUSDCBalance = usdc.balanceOf(account);

        // Approval and Stake
        vm.startPrank(account);
        usdc.approve(address(portal_USDC), fuzzAmount);
        portal_USDC.stake(fuzzAmount);
        vm.stopPrank();

        uint256 finalUSDCBalance = usdc.balanceOf(account);

        // Verifications
        assertEq(initialUSDCBalance - fuzzAmount, finalUSDCBalance, "Alice's balance after staking is incorrect.");
        assertEq(portal_USDC.totalPrincipalStaked(), fuzzAmount, "The total principal staked does not match the stake amount.");
    }

    // Deploy the ERC20 contract for mintable Portal Energy
    function helper_createPortalEnergyToken() public {
        portal_USDC.create_portalEnergyToken();
    }

    // Increase allowance of tokens used by the USDC Portal
    function helper_setApprovalsInLP_USDC() public {
        virtualLP.increaseAllowanceDualStaking();
        virtualLP.increaseAllowanceSingleStaking(address(portal_USDC));
        virtualLP.increaseAllowanceVault(address(portal_USDC));
    }

    // Increase allowance of tokens used by the ETH Portal
    function helper_setApprovalsInLP_ETH() public {
        virtualLP.increaseAllowanceDualStaking();
        virtualLP.increaseAllowanceSingleStaking(address(portal_ETH));
        virtualLP.increaseAllowanceVault(address(portal_ETH));
    }

    // send USDC to LP when balance is required
    function helper_sendUSDCtoLP() public {
        vm.prank(usdcSender);
        usdc.transfer(address(virtualLP), usdcSendAmount); // Send 1k USDC to LP
    }

    // simulate a full convert() cycle
    function helper_executeConvert() public {
        helper_sendUSDCtoLP();
        vm.startPrank(psmSender);
        psm.approve(address(virtualLP), 1e55);
        virtualLP.convert(
            _PRINCIPAL_TOKEN_ADDRESS_USDC,
            msg.sender,
            1,
            block.timestamp
        );
        vm.stopPrank();
    }

}