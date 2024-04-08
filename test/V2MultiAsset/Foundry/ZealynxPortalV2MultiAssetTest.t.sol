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

    function _setApprovalsInLP_ETH() public {
        virtualLP.increaseAllowanceDualStaking();
        virtualLP.increaseAllowanceSingleStaking(address(portal_ETH));
        virtualLP.increaseAllowanceVault(address(portal_ETH));
    }

    function _setApprovalsInLP_USDC() public {
        virtualLP.increaseAllowanceDualStaking();
        virtualLP.increaseAllowanceSingleStaking(address(portal_USDC));
        virtualLP.increaseAllowanceVault(address(portal_USDC));
    }

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
        _setApprovalsInLP_ETH();

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
        vm.assume(timePassed > 0 days && timePassed < 10_000 days);

        _prepareLP();
        _setApprovalsInLP_USDC();

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
        _setApprovalsInLP_ETH();

        uint256 balanceBefore2 = Alice.balance;
        uint256 minOperationalAmount = 1e4; 
        vm.assume(_amountStake >= minOperationalAmount && _amountStake <= balanceBefore2);
        vm.assume(timePassed > 0 days && timePassed < 10_000 days);

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
        _setApprovalsInLP_USDC();

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
        _setApprovalsInLP_USDC();

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

    function testEmptyAccountMintNFTposition(uint256 _amountStake) public {
        portal_USDC.create_portalNFT();
        // STAKE //
        _prepareLP();
        _setApprovalsInLP_USDC();

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

    function testRedeemNFTPosition(uint256 _amountStake) public {
        testMintNFTPositionFixedAccountAmount(_amountStake);
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

    function testRevertRedeemNFTposition(uint256 _amountStake) public {
        testMintNFTPositionFixedAccountAmount(_amountStake);
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

    // ============================================
    // ==           BUY PORTAL ENERGY            ==
    // ============================================

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

    function testRevertBuyPortalEnergy(uint256 _minReceived, uint256 _amountInputPSM) public {
        _prepareLP();

        uint256 minOperationalAmount = 1e4; 
        uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
        vm.assume(_minReceived >= minOperationalAmount && _minReceived <= aliceInitialUSDCBalance);
        vm.assume(_amountInputPSM < _minReceived && _amountInputPSM != 0);
        
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
        portal_USDC.buyPortalEnergy(Alice, _amountInputPSM, _minReceived, block.timestamp);
    }

  ////////////// HELPER FUNCTIONS /////////////

    function helper_Stake(address account, uint256 _amountStake) public {
        // STAKE
        uint256 initialUSDCBalance = usdc.balanceOf(account);

        // Approval and Stake
        vm.startPrank(account);
        usdc.approve(address(portal_USDC), _amountStake);
        portal_USDC.stake(_amountStake);
        vm.stopPrank();

        uint256 finalUSDCBalance = usdc.balanceOf(account);

        // Verifications
        assertEq(initialUSDCBalance - _amountStake, finalUSDCBalance, "Alice's balance after staking is incorrect.");
        assertEq(portal_USDC.totalPrincipalStaked(), _amountStake, "The total principal staked does not match the stake amount.");
    }
}