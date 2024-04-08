   
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


contract ItyfuzzVirtuaLp is Test {
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


    // ============================================
    // ==            REGISTER PORTAL             ==
    // ============================================

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
        // Action
        vm.expectRevert(ErrorsLib.OwnerNotExpired.selector);
        virtualLP.removeOwner();
    }

    // ============================================
    // ==        DEPOSIT TO YIELD SOURCE         ==
    // ============================================

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
    
    function test_fuzz_deposit_to_yield_source(uint256 _amountRaw) public {
        uint256 _amount = bound(_amountRaw, 1, 1e7);

        _prepareYieldSourceUSDC(_amount);

        // Action
        vm.prank(address(portal_USDC));
        virtualLP.depositToYieldSource(address(usdc), _amount);

        // Check that stake was processed correctly in Vault and staking contract
        uint256 depositShares = IWater(USDC_WATER).convertToShares(_amount);
        uint256 stakedShares = ISingleStaking(SINGLE_STAKING).getUserAmount(
            _POOL_ID_USDC,
            address(virtualLP)
        );

        // Verification
        assertTrue(usdc.balanceOf(address(portal_USDC)) == 0);
        assertTrue(depositShares == stakedShares);
    }


    // ============================================
    // ==       WITHDRAW FROM YIELD SOURCE       ==
    // ============================================

    function test_fuzz_withdraw_from_yield_source(uint256 _amountRaw) public {
        uint256 _amount = bound(_amountRaw, 2, 1e7); // _amount > 1 to ensure netReceived calculation is valid

        // Setup a yield source with a specific amount
        _prepareYieldSourceUSDC(_amount);
        
        // Deposit to the yield source as the setup action
        vm.prank(address(portal_USDC));
        virtualLP.depositToYieldSource(address(usdc), _amount);

        // Record the starting balance of the user
        uint256 balanceUser1Start = usdc.balanceOf(Alice);
        
        // Simulate time passing to allow for yield accumulation
        vm.warp(block.timestamp + 100);

        // Calculate shares to withdraw based on the initial amount
        uint256 withdrawShares = IWater(USDC_WATER).convertToShares(_amount);
        // Calculate the gross amount receivable before fees
        uint256 grossReceived = IWater(USDC_WATER).convertToAssets(withdrawShares);
        // Use the denominator for fee calculation
        uint256 denominator = IWater(USDC_WATER).DENOMINATOR();
        // Calculate the fee to be deducted from the grossReceived
        uint256 fees = (grossReceived * IWater(USDC_WATER).withdrawalFees()) / denominator;
        // The net amount receivable after fees
        uint256 netReceived = grossReceived - fees;

        // Withdraw action simulated
        vm.prank(address(portal_USDC));
        virtualLP.withdrawFromYieldSource(address(usdc), Alice, _amount);

        // Verify the user's balance increased by the net received amount
        assertTrue(usdc.balanceOf(Alice) == balanceUser1Start + netReceived);
    }


    // ============================================
    // ==              PSM CONVERTER             ==
    // ============================================

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
        vm.prank(psmSender);
        virtualLP.convert(_PRINCIPAL_TOKEN_ADDRESS_USDC, Alice, 1, block.timestamp + 1 days);

        // Verification
        uint256 expectedNewReward = (_AMOUNT_TO_CONVERT * FUNDING_REWARD_SHARE) / 100;
        assertTrue(virtualLP.fundingRewardPool() == initialRewardPool + expectedNewReward);
    }


    function test_correct_token_transfer() public {
        prepare_convert(); 

        uint256 contractBalanceBefore = usdc.balanceOf(address(virtualLP)); 
        uint256 recipientBalanceBefore = usdc.balanceOf(Alice);

        // Action
        vm.prank(Alice);
        virtualLP.convert(
            _PRINCIPAL_TOKEN_ADDRESS_USDC,
            Alice,
            1, 
            block.timestamp + 1 
        );

        // Check the recipient received the tokens correctly
        uint256 recipientBalanceAfter = usdc.balanceOf(Alice);
        assert(recipientBalanceAfter == recipientBalanceBefore + contractBalanceBefore);

        uint256 contractBalanceAfter = usdc.balanceOf(address(virtualLP));
        assert(contractBalanceAfter == 0);
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
        vm.expectRevert(ErrorsLib.DeadlineExpired.selector);
        virtualLP.convert(_PRINCIPAL_TOKEN_ADDRESS_USDC, Alice, 100, block.timestamp - 1 days);
    }

    function test_revert_insufficient_balance() public {
        prepare_convert();

        // Action
        vm.expectRevert(ErrorsLib.InsufficientReceived.selector);
        virtualLP.convert(_PRINCIPAL_TOKEN_ADDRESS_USDC, Alice, 1e18, block.timestamp + 1 days);
    }

    function test_fuzz_convert(uint256 _deadlineRaw) public {
        uint256 adjustedDeadline = _deadlineRaw % (1e10 - 1) + 1; 
        uint256 _deadline = block.timestamp + adjustedDeadline;

        prepare_convert();

        virtualLP.convert(_PRINCIPAL_TOKEN_ADDRESS_USDC, Bob, 1, _deadline);
    }




}
