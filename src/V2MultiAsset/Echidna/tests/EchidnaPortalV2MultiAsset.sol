// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../EchidnaLogic.sol";
import {IWater} from "src/V2MultiAsset/interfaces/IWater.sol";
import {ISingleStaking} from "src/V2MultiAsset/interfaces/ISingleStaking.sol";


contract EchidnaPortalV2MultiAsset is EchidnaLogic {
    
    constructor() payable {}

    function _prepareStake(uint256 _amount) internal {
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

    function _prepareStakeUSDC(uint256 _amount) internal {
        _prepareStake(_amount);

        // Set up approvals on LP for USDC
        virtualLP.increaseAllowanceDualStaking();
        virtualLP.increaseAllowanceSingleStaking(address(portal_USDC));
        virtualLP.increaseAllowanceVault(address(portal_USDC));

        // Approval and Stake
        hevm.prank(USER1);
        usdc.approve(address(portal_USDC), _amount);
        hevm.prank(USER1);
        portal_USDC.stake(_amount);
    }

    function _prepareStakeETH(uint256 _amount) internal {
        _prepareStake(_amount);

        // Set up approvals on LP for ETH
        virtualLP.increaseAllowanceDualStaking();
        virtualLP.increaseAllowanceSingleStaking(address(portal_ETH));
        virtualLP.increaseAllowanceVault(address(portal_ETH));

        // Approval and Stake
        hevm.prank(USER1);
        portal_ETH.stake{value: _amount}(_amount);
    }

    function _prepareMintNFT(uint256 _amountStake) internal {
        portal_USDC.create_portalNFT();
        _prepareStakeUSDC(_amountStake);
        hevm.prank(USER1);
        portal_USDC.mintNFTposition(USER3);
    }

    // ============================================
    // ==                  STAKE                 ==
    // ============================================

    function testFuzzingStakeUSDC(uint256 fuzzAmount) public {
        // Setup the system
        uint256 user1InitialUSDCBalance = 1e12;
        require(fuzzAmount > 0);
        require(fuzzAmount <= user1InitialUSDCBalance);
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

        // Set up approvals on LP for USDC
        virtualLP.increaseAllowanceDualStaking();
        virtualLP.increaseAllowanceSingleStaking(address(portal_USDC));
        virtualLP.increaseAllowanceVault(address(portal_USDC));

        // Approval and Stake
        hevm.prank(USER1);
        usdc.approve(address(portal_USDC), fuzzAmount);
        hevm.prank(USER1);
        portal_USDC.stake(fuzzAmount);

        uint256 user1FinalUSDCBalance = usdc.balanceOf(USER1);

        // Verifications
        assert(user1InitialUSDCBalance - fuzzAmount == user1FinalUSDCBalance); // , "USER1's balance after staking is incorrect.");
        Debugger.log("USDC total principal staked: ", portal_USDC.totalPrincipalStaked());
        assert(portal_USDC.totalPrincipalStaked() == fuzzAmount); // , "The total principal staked does not match the stake amount.");
    }

    function testFuzzingStakeETH(uint256 fuzzAmount) public {
        // Prepare the system
        // (bool sent, ) = payable(USER1).call{value: 1 ether}("");
        uint256 balanceBefore = USER1.balance;
        Debugger.log("balanceBefore: ", balanceBefore);

        require(fuzzAmount != 0);
        require(fuzzAmount <= balanceBefore);

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

        virtualLP.increaseAllowanceDualStaking();
        virtualLP.increaseAllowanceSingleStaking(address(portal_ETH));
        virtualLP.increaseAllowanceVault(address(portal_ETH));

        // Approval and Stake
        hevm.prank(USER1);
        try portal_ETH.stake{value: fuzzAmount}(fuzzAmount) {
            // continue
        } catch {
            // Verification
            assert(false);
        }

        uint256 user1FinalETHBalance =  USER1.balance;
        Debugger.log("user1FinalETHBalance: ", user1FinalETHBalance);
        Debugger.log("ETH total principal staked: ", portal_ETH.totalPrincipalStaked());

        // Verifications
        assert(balanceBefore - fuzzAmount == user1FinalETHBalance); // , "USER1's balance after staking is incorrect.");
        assert(portal_ETH.totalPrincipalStaked() == fuzzAmount); // "The total principal staked does not match the stake amount.");
    }

    // ============================================
    // ==                 UNSTAKE                ==
    // ============================================

    function testFuzzingUnstakeUSDC(/*uint256 fuzzAmount*/) public {
        uint256 fuzzAmount = 1e7;

        // require(fuzzAmount != 0);
        // require(fuzzAmount < usdcAmount);

        _prepareStakeUSDC(fuzzAmount);

        // UNSTAKE
        uint256 balanceBefore = usdc.balanceOf(USER1);
        uint256 withdrawShares = IWater(USDC_WATER).convertToShares(fuzzAmount);
        uint256 grossReceived = IWater(USDC_WATER).convertToAssets(withdrawShares);
        uint256 denominator = IWater(USDC_WATER).DENOMINATOR();
        uint256 fees = (grossReceived * IWater(USDC_WATER).withdrawalFees()) / denominator;
        uint256 netReceived = grossReceived - fees;

        hevm.warp(block.timestamp + 100);

        hevm.prank(USER1);
        try portal_USDC.unstake(fuzzAmount) {
            // continue
        } catch {
            // Verification
            assert(false);
        }

        uint256 balanceAfter = usdc.balanceOf(USER1);

        assert(balanceBefore == usdcAmount - fuzzAmount);
        assert(balanceAfter == balanceBefore + netReceived);
        assert(balanceAfter <= usdcAmount);
    }

    // function testFuzzUnstakeETH() public {
    //     uint256 fuzzAmount = 1e7;
    //     uint256 balanceBefore = USER1.balance;
    //     uint256 minOperationalAmount = 1e4; 

    //     // require(fuzzAmount > minOperationalAmount);
    //     // require(fuzzAmount < balanceBefore);

    //     _prepareStakeETH(fuzzAmount);

    //     // UNSTAKE
    //     uint256 withdrawShares = IWater(WETH_WATER).convertToShares(fuzzAmount);
    //     uint256 grossReceived = IWater(WETH_WATER).convertToAssets(withdrawShares);
    //     uint256 denominator = IWater(WETH_WATER).DENOMINATOR();
    //     uint256 fees = (grossReceived * IWater(WETH_WATER).withdrawalFees()) / denominator;
    //     uint256 netReceived = grossReceived - fees;

    //     hevm.warp(block.timestamp + 100);

    //     hevm.prank(USER1);
    //     try portal_ETH.unstake(fuzzAmount) {
    //         // continue
    //     } catch {
    //         // Verification
    //         assert(false);
    //     }

    //     uint256 balanceAfter = USER1.balance;

    //     assert(balanceBefore == 1e18 - fuzzAmount);
    //     assert(balanceAfter == balanceBefore + netReceived);
    //     assert(balanceAfter <= 1e18);
    // }

    // ============================================
    // ==            CREATE PORTAL NFT           ==
    // ============================================

    function testCreatePortalNFT() public {
        require(portal_USDC.portalNFTcreated() == false);

        try portal_USDC.create_portalNFT() {
            // continue
        } catch {
            // Verification
            assert(false);
        }
        assert(portal_USDC.portalNFTcreated() == true);
        assert(address(portal_USDC.portalNFT()) != address(0));
    }

    // ============================================
    // ==            MINT NFT POSITION           ==
    // ============================================

    function testMintNFTPositionUpdateAccount(uint256 _amountStake, uint256 _amountAccount) public {
        uint256 user1InitialUSDCBalance = usdc.balanceOf(USER1);
        uint256 minOperationalAmount = 1e4; 
        require(_amountStake >= minOperationalAmount);
        require(_amountStake <= user1InitialUSDCBalance);
        require(_amountAccount >= minOperationalAmount);
        require(_amountAccount <= user1InitialUSDCBalance);
        require(_amountAccount != _amountStake);
        
        portal_USDC.create_portalNFT();
        _prepareStakeUSDC(_amountStake);

        (
            ,
            uint256 lastMaxLockDurationBefore,
            uint256 stakeBalanceBefore,
            ,
            uint256 peBalanceBefore,
            ,

        ) = portal_USDC.getUpdateAccount(USER1, 0, true);

        hevm.prank(USER1);
        try portal_USDC.mintNFTposition(USER3) {
            // continue
        } catch {
            // Verification
            assert(false);
        }

        (
            ,
            uint256 lastMaxLockDurationAfter,
            uint256 stakeBalanceAfter,
            ,
            uint256 peBalanceAfter,
            ,

        ) = portal_USDC.getUpdateAccount(USER1, _amountAccount, true);
        
        Debugger.log("lastMaxLockDurationAfter: ", lastMaxLockDurationAfter);
        Debugger.log("stakeBalanceAfter: ", stakeBalanceAfter);
        Debugger.log("peBalanceAfter: ", peBalanceAfter);

        assert(lastMaxLockDurationAfter == lastMaxLockDurationBefore);
        assert(stakeBalanceAfter == _amountAccount);
    }

    function testMintNFTPositionNFTPortal(uint256 _amountStake, uint256 _amountAccount) public {
        
        uint256 user1InitialUSDCBalance = usdc.balanceOf(USER1);
        uint256 minOperationalAmount = 1e4; 
        require(_amountStake >= minOperationalAmount);
        require(_amountStake <= user1InitialUSDCBalance);
        require(_amountAccount >= minOperationalAmount);
        require(_amountAccount <= user1InitialUSDCBalance);
        require(_amountAccount != _amountStake);
        
        portal_USDC.create_portalNFT();
        _prepareStakeUSDC(_amountStake);

        (
            ,
            ,
            uint256 stakeBalanceBefore,
            ,
            uint256 peBalanceBefore,
            ,

        ) = portal_USDC.getUpdateAccount(USER1, 0, true);

        hevm.prank(USER1);
        portal_USDC.mintNFTposition(USER3);

        (
            uint256 nftMintTime,
            uint256 nftLastMaxLockDuration,
            uint256 nftStakedBalance,
            uint256 nftPortalEnergy
        ) = portal_USDC.portalNFT().accounts(1);

        assert(address(portal_USDC.portalNFT()) != address(0));
        assert(nftMintTime == block.timestamp);
        assert(nftLastMaxLockDuration == portal_USDC.maxLockDuration());
        assert(nftStakedBalance == stakeBalanceBefore);
        assert(nftPortalEnergy == peBalanceBefore);
    }

    // ============================================
    // ==          REDEEM NFT POSITION           ==
    // ============================================

    function testRedeemNFTposition(uint256 _amountStake, uint256 timePassed) public {
        uint256 user1InitialUSDCBalance = usdc.balanceOf(USER1);
        uint256 minOperationalAmount = 1e4; 
        require(_amountStake >= minOperationalAmount);
        require(_amountStake <= user1InitialUSDCBalance);
        require(timePassed > 1 days);
        require(timePassed <= 10000 days);

        uint256 amountStake = _amountStake;

        _prepareMintNFT(amountStake);
        
        (
            ,
            ,
            uint256 stakeBalanceBefore,
            ,
            uint256 peBalanceBefore,
            ,

        ) = portal_USDC.getUpdateAccount(USER3, 0, true);

        hevm.warp(block.timestamp + timePassed);
        hevm.prank(USER3);
        try portal_USDC.redeemNFTposition(1) {
            // continue
        } catch {
            // Verification
            assert(false);
        }

        hevm.prank(USER3);
        (
            ,
            uint256 lastMaxLockDurationAfter,
            uint256 stakeBalanceAfter,
            ,
            uint256 peBalanceAfter,
            ,

        ) = portal_USDC.getUpdateAccount(USER3, 0, true);

        uint256 portalEnergyEarned = stakeBalanceBefore * timePassed;
        uint256 maxLockDifference = maxLockDuration - lastMaxLockDurationAfter;
        uint256 portalEnergyIncrease = stakeBalanceBefore * maxLockDifference;
        uint256 portalEnergyNetChange =
                ((portalEnergyEarned + portalEnergyIncrease) * 1e18) /
                DENOMINATOR;
        uint256 adjustedPE = 0 * maxLockDuration * 1e18;
        uint256 portalEnergyAdjustment = adjustedPE / DENOMINATOR;

        uint256 expectedPEBalance = peBalanceBefore +
                portalEnergyNetChange +
                portalEnergyAdjustment;
        
        uint256 expectedPEBalanceMarginUp = expectedPEBalance + 1;
        uint256 expectedPEBalanceMarginDown = expectedPEBalance - 1;

        assert(stakeBalanceAfter == amountStake);
        assert(
            peBalanceAfter == expectedPEBalance
            ||
            peBalanceAfter == expectedPEBalanceMarginUp 
            || 
            peBalanceAfter == expectedPEBalanceMarginDown
        );
    }
}
