// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {PortalV2MultiAsset} from "src/V2MultiAsset/PortalV2MultiAsset.sol";
import {MintBurnToken} from "src/V2MultiAsset/MintBurnToken.sol";
import {VirtualLP} from "src/V2MultiAsset/VirtualLP.sol";
import {EventsLib} from "../libraries/EventsLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDualStaking} from "src/V2MultiAsset/interfaces/IDualStaking.sol";
import {IPortalV2MultiAsset} from "src/V2MultiAsset/interfaces/IPortalV2MultiAsset.sol";


import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWater} from "src/V2MultiAsset/interfaces/IWater.sol";
import {ISingleStaking} from "src/V2MultiAsset/interfaces/ISingleStaking.sol";


contract ItyfuzzPortalV2MultiAsset is Test {
    MintBurnToken internal psmToken;
    VirtualLP internal virtualLP;
 
    // External token addresses
    address constant WETH_ADDRESS = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant PSM_ADDRESS =
        0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5;
    address constant esVKA = 0x95b3F9797077DDCa971aB8524b439553a220EB2A;

    uint256 constant _POOL_ID_USDC = 5;
    uint256 constant _POOL_ID_WETH = 10;

    address internal constant USDC_WATER =
        0x9045ae36f963b7184861BDce205ea8B08913B48c;
    address internal constant WETH_WATER =
        0x8A98929750e6709Af765F976c6bddb5BfFE6C06c;

    address internal constant _PRINCIPAL_TOKEN_ADDRESS_USDC =
        0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address internal constant _PRINCIPAL_TOKEN_ADDRESS_ETH = address(0);

    // General constants
    uint256 constant _TERMINAL_MAX_LOCK_DURATION = 157680000;
    uint256 internal constant SECONDS_PER_YEAR = 31536000; // seconds in a 365 day year
    uint256 internal maxLockDuration = 7776000; // 7776000 starting value for maximum allowed lock duration of user´s balance in seconds (90 days)
    uint256 internal constant OWNER_DURATION = 31536000; // 1 Year
    uint256 internal constant FUNDING_MAX_RETURN_PERCENT = 1000; // maximum redemption value percent of bTokens (must be >100)

    // Portal Constructor values
    uint256 constant _TARGET_CONSTANT_USDC = 440528634361 * 1e36;
    uint256 constant _TARGET_CONSTANT_WETH = 125714213 * 1e36;

    uint256 internal constant FUNDING_APR = 36; // annual redemption value increase (APR) of bTokens
    uint256 constant _FUNDING_PHASE_DURATION = 604800; // 7 days
    uint256 constant _FUNDING_MIN_AMOUNT = 1e25; // 10M PSM

    uint256 constant _DECIMALS = 18;
    uint256 constant _DECIMALS_USDC = 6;

    uint256 constant _AMOUNT_TO_CONVERT = 100000 * 1e18;
    uint256 internal constant FUNDING_REWARD_SHARE = 10; // 10% of yield goes to the funding pool until investors are paid back

    string _META_DATA_URI = "abcd";

    // time
    uint256 timestamp;
    uint256 fundingPhase;
    uint256 ownerExpiry;
    uint256 hundredYearsLater;

    // Token Instances
    IERC20 psm = IERC20(PSM_ADDRESS);
    IERC20 usdc = IERC20(_PRINCIPAL_TOKEN_ADDRESS_USDC);
    IERC20 weth = IERC20(WETH_ADDRESS);

    // Portals & LP
    PortalV2MultiAsset internal portal_USDC;
    PortalV2MultiAsset internal portal_ETH;

    // Simulated USDC distributor
    address usdcSender = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    // PSM Treasury
    address psmSender = 0xAb845D09933f52af5642FC87Dd8FBbf553fd7B33;

        // Vaultka staking contracts
    address constant SINGLE_STAKING =
        0x314223E2fA375F972E159002Eb72A96301E99e22;
    address constant DUAL_STAKING = 0x31Fa38A6381e9d1f4770C73AB14a0ced1528A65E;

    // starting token amounts
    uint256 usdcAmount = 1e12; // 1M USDC
    uint256 psmAmount = 1e25; // 10M PSM
    uint256 usdcSendAmount = 1e9; // 1k USDC
    
    // prank addresses
    address payable Alice = payable(0x46340b20830761efd32832A74d7169B29FEB9758);
    address payable Bob = payable(0xDD56CFdDB0002f4d7f8CC0563FD489971899cb79);
    address payable Karen = payable(0x3A30aaf1189E830b02416fb8C513373C659ed748);

    /////////////////////////////////////////////
    ///////////////// SETUP /////////////////////
    /////////////////////////////////////////////

    function setUp() public {
        // Create Virtual LP instance
        virtualLP = new VirtualLP(
            psmSender,
            _AMOUNT_TO_CONVERT,
            _FUNDING_PHASE_DURATION,
            _FUNDING_MIN_AMOUNT
        );
        address _VIRTUAL_LP = address(virtualLP);

        // Create Portal instances
        portal_USDC = new PortalV2MultiAsset(
            _VIRTUAL_LP,
            _TARGET_CONSTANT_USDC,
            _PRINCIPAL_TOKEN_ADDRESS_USDC,
            _DECIMALS_USDC,
            "USD Coin",
            "USDC",
            _META_DATA_URI
        );
        portal_ETH = new PortalV2MultiAsset(
            _VIRTUAL_LP,
            _TARGET_CONSTANT_WETH,
            _PRINCIPAL_TOKEN_ADDRESS_ETH,
            _DECIMALS,
            "ETHER",
            "ETH",
            _META_DATA_URI
        );

        // creation time
        timestamp = block.timestamp;
        fundingPhase = timestamp + _FUNDING_PHASE_DURATION;
        ownerExpiry = timestamp + OWNER_DURATION;
        hundredYearsLater = timestamp + 100 * SECONDS_PER_YEAR;

        // Deal tokens to addresses
        vm.deal(Alice, 1 ether);
        vm.prank(psmSender);
        psm.transfer(Alice, psmAmount);
        vm.prank(usdcSender);
        usdc.transfer(Alice, usdcAmount);

        vm.deal(Bob, 1 ether);
        vm.prank(psmSender);
        psm.transfer(Bob, psmAmount);
        vm.prank(usdcSender);
        usdc.transfer(Bob, usdcAmount);

        vm.deal(Karen, 1 ether);
        vm.prank(psmSender);
        psm.transfer(Karen, psmAmount);
        vm.prank(usdcSender);
        usdc.transfer(Karen, usdcAmount);
    }



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
        vm.startPrank(psmSender);
        psm.approve(address(virtualLP), 1e55);
        virtualLP.contributeFunding(_FUNDING_MIN_AMOUNT);
        vm.stopPrank();
    }

    // activate the Virtual LP
    function _activateLP() internal {
        vm.warp(fundingPhase);
        virtualLP.activateLP();
    }

    // send USDC to LP when balance is required
    function _sendUSDCtoLP() internal {
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
        _sendUSDCtoLP();
        vm.prank(psmSender);
        psm.approve(address(virtualLP), 1e55);
        vm.prank(psmSender);
    }

    function _assertPortalRegistered(
        address testPortal,
        address testAsset,
        address testVault,
        uint256 testPid
    ) internal view {
        assertTrue(virtualLP.registeredPortals(testPortal) == true);
        assertTrue(virtualLP.vaults(testPortal, testAsset) == testVault);
        assertTrue(virtualLP.poolID(testPortal, testAsset) == testPid); 
    }





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

    function testFuzzingStakeUSDC(uint256 _amountStakeRaw) public { //ok
        _prepareLP();

        virtualLP.increaseAllowanceDualStaking();
        virtualLP.increaseAllowanceSingleStaking(address(portal_USDC));
        virtualLP.increaseAllowanceVault(address(portal_USDC));

        deal(address(usdc), Alice, 1e10);
        uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);

        uint256 _amountStake = bound(_amountStakeRaw, 100, aliceInitialUSDCBalance); 

        // Aprobación y stake
        vm.startPrank(Alice);
        usdc.approve(address(portal_USDC), _amountStake);
        portal_USDC.stake(_amountStake);
        vm.stopPrank();

        uint256 aliceFinalUSDCBalance = usdc.balanceOf(Alice);

        // Verificaciones
        assertEq(aliceInitialUSDCBalance - _amountStake, aliceFinalUSDCBalance, "Alice's balance after staking is incorrect.");
        assertEq(portal_USDC.totalPrincipalStaked(), _amountStake, "The total principal staked does not match the stake amount.");
    }


    function testFuzzingStakeETH(uint256 _amountStakeRaw) public { //ok
        _prepareLP();

        virtualLP.increaseAllowanceDualStaking();
        virtualLP.increaseAllowanceSingleStaking(address(portal_ETH));
        virtualLP.increaseAllowanceVault(address(portal_ETH));

        uint256 balanceBefore = Alice.balance;
        uint256 _amountStake = bound(_amountStakeRaw, 100, balanceBefore);

        vm.startPrank(Alice);
        portal_ETH.stake{value: _amountStake}(_amountStake);

        vm.stopPrank();

        uint256 aliceFinalETHBalance = Alice.balance;

        assertEq(balanceBefore - _amountStake, aliceFinalETHBalance, "Alice's balance after staking is incorrect.");
        assertEq(portal_ETH.totalPrincipalStaked(), _amountStake, "The total principal staked does not match the stake amount.");
    }

    function testFuzz_Revert_stake_PortalNotRegistered(uint256 _amountStakeRaw) public { //ok
        _create_bToken();
        _fundLP();
        _activateLP();

        deal(address(usdc), Alice, 1e10);
        uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
        uint256 _amountStake = bound(_amountStakeRaw, 100, aliceInitialUSDCBalance);

        vm.startPrank(Alice);
        usdc.approve(address(portal_USDC), _amountStake);
        vm.expectRevert(ErrorsLib.PortalNotRegistered.selector);
        portal_USDC.stake(_amountStake);
        vm.stopPrank();
    }

    function testFuzz_Revert_stake_Zero(uint256 _amountStakeRaw) public { //ok
        _prepareLP();

        deal(address(usdc), Alice, 1e10);
        uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
        uint256 _amountStake = bound(_amountStakeRaw, 100, aliceInitialUSDCBalance);

        vm.startPrank(Alice);
        usdc.approve(address(portal_USDC), _amountStake);
        vm.expectRevert(ErrorsLib.InvalidAmount.selector);
        portal_USDC.stake(0);
        vm.stopPrank();
    }

    function testFuzz_Revert_stake_Ether(uint256 _amountStakeRaw) public { //ok
        _prepareLP();

        deal(address(usdc), Alice, 1e10);
        uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
        uint256 _amountStake = bound(_amountStakeRaw, 100, aliceInitialUSDCBalance);

        vm.startPrank(Alice);
        usdc.approve(address(portal_USDC), _amountStake);
        vm.expectRevert(ErrorsLib.NativeTokenNotAllowed.selector);
        portal_USDC.stake{value: _amountStake}(_amountStake);
        vm.stopPrank();
    }


    function testFuzz_Revert_stake_0_InvalidAmount(uint256 _amountStakeRaw) public { //ok
        _prepareLP();
        _setApprovalsInLP_ETH();

        deal(address(weth), Alice, 1e10);
        uint256 aliceInitialETHBalance = Alice.balance;
        uint256 _amountStake = bound(_amountStakeRaw, 100, aliceInitialETHBalance);

        vm.startPrank(Alice);
        vm.expectRevert(ErrorsLib.InvalidAmount.selector);
        portal_ETH.stake{value: 0}(_amountStake);
        vm.stopPrank();
    }

        // ============================================
        // ==                 UNSTAKE                ==
        // ============================================
        
    function testUnstakeUSDC(uint256 _amountStakeRaw, uint256 timePassedRaw) public { //ok
        uint256 timePassed = bound(timePassedRaw, 1 days, 10_000 days);

        _prepareLP();
        _setApprovalsInLP_USDC();

        uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
        uint256 minOperationalAmount = 1e4;
        uint256 _amountStake = bound(_amountStakeRaw, minOperationalAmount, aliceInitialUSDCBalance);

        vm.startPrank(Alice);
        helper_Stake(Alice, _amountStake);
        vm.stopPrank();

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

        assertEq(balanceBefore + netReceived, balanceAfter);
    }

    function testUnstakeETH(uint256 _amountStakeRaw, uint256 timePassedRaw) public { //ok
        uint256 balanceBefore = Alice.balance;
        uint256 minOperationalAmount = 1e4;
        uint256 _amountStake = bound(_amountStakeRaw, minOperationalAmount, balanceBefore);
        uint256 timePassed = bound(timePassedRaw, 1 days, 10_000 days);

        _prepareLP();
        _setApprovalsInLP_ETH();

        vm.startPrank(Alice);
        portal_ETH.stake{value: _amountStake}(_amountStake);
        vm.stopPrank();

        uint256 withdrawShares = IWater(WETH_WATER).convertToShares(_amountStake);
        uint256 grossReceived = IWater(WETH_WATER).convertToAssets(withdrawShares);
        uint256 denominator = IWater(WETH_WATER).DENOMINATOR();
        uint256 fees = (grossReceived * IWater(WETH_WATER).withdrawalFees()) / denominator;
        uint256 netReceived = grossReceived - fees;

        vm.warp(block.timestamp + timePassed);

        vm.prank(Alice);
        portal_ETH.unstake(_amountStake);

        uint256 balanceAfter = Alice.balance;

        assertEq(balanceBefore + netReceived, balanceAfter);
    }


        // ============================================
        // ==            MINT NFT POSITION           ==
        // ============================================

    function testMintNFTposition(uint256 _amountStakeRaw, uint256 _amountAccountRaw) public {
        portal_USDC.create_portalNFT();
        // STAKE //
        _prepareLP();
        _setApprovalsInLP_USDC();

        uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
        uint256 minOperationalAmount = 1e4;
        uint256 _amountStake = bound(_amountStakeRaw, minOperationalAmount, aliceInitialUSDCBalance);
        uint256 _amountAccountRawBounded = bound(_amountAccountRaw, minOperationalAmount, aliceInitialUSDCBalance);

        // Adjust _amountAccount if it's equal to _amountStake
        uint256 _amountAccount = _amountAccountRawBounded != _amountStake ? _amountAccountRawBounded 
                            : _amountAccountRawBounded + 1 <= aliceInitialUSDCBalance ? _amountAccountRawBounded + 1 
                            : _amountAccountRawBounded - 1;

        vm.startPrank(Alice);
        helper_Stake(Alice, _amountStake);
        vm.stopPrank();

        (,, uint256 stakeBalanceBefore,, uint256 peBalanceBefore,,) = portal_USDC.getUpdateAccount(Alice, 0, true);

        vm.prank(Alice);
        portal_USDC.mintNFTposition(Karen);

        (,, uint256 stakeBalanceAfter,, uint256 peBalanceAfter,,) = portal_USDC.getUpdateAccount(Alice, _amountAccount, true);

        assertTrue(stakeBalanceBefore > 0);
        assertTrue(peBalanceBefore > 0);
        assertEq(stakeBalanceAfter, _amountAccount);

        (uint256 nftMintTime, uint256 nftLastMaxLockDuration, uint256 nftStakedBalance, uint256 nftPortalEnergy) = portal_USDC.portalNFT().accounts(1);

        assertTrue(address(portal_USDC.portalNFT()) != address(0));
        assertEq(nftMintTime, block.timestamp);
        assertEq(nftLastMaxLockDuration, portal_USDC.maxLockDuration());
        assertEq(nftStakedBalance, stakeBalanceBefore);
        assertEq(nftPortalEnergy, peBalanceBefore);
    }


    function testMintNFTPositionFixedAccountAmount(uint256 _amountStakeRaw) public { //ok
        portal_USDC.create_portalNFT();
        // STAKE //
        _prepareLP();
        _setApprovalsInLP_USDC();

        uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
        uint256 minOperationalAmount = 1e4;
        uint256 _amountStake = bound(_amountStakeRaw, minOperationalAmount, aliceInitialUSDCBalance);

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


        function testEmptyAccountMintNFTposition(uint256 _amountStakeRaw) public {
        portal_USDC.create_portalNFT();
        // STAKE //
        _prepareLP();
        _setApprovalsInLP_USDC();

        uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
        uint256 minOperationalAmount = 1e4; 
        uint256 _amountStake = bound(_amountStakeRaw, minOperationalAmount, aliceInitialUSDCBalance);

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

    function testRedeemNFTPosition(uint256 _amountStakeRaw) public {
        testMintNFTPositionFixedAccountAmount(_amountStakeRaw);
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

    function testRevertRedeemNFTposition(uint256 _amountStakeRaw) public {
        testMintNFTPositionFixedAccountAmount(_amountStakeRaw);
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

      //////////// HELPER FUNCTIONS /////////////

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