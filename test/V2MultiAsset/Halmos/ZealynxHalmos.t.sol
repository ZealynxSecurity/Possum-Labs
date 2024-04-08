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

import{MockToken} from "../mocks/HMockToken.sol";

import {SingleStakingV2} from "src/onchain/SingleStakingV2.sol";
import {EthWater} from "src/onchain/Water.sol";
import {FiatTokenV2_2} from "src/onchain/FiatTokenV2_2.sol";

import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {HandlerVirtual} from "./HandlerVirtual.sol";



contract Halmos_ZealynxTest is SymTest, Test {
// External token addresses

    uint256 constant _POOL_ID_USDC = 5;
    uint256 constant _POOL_ID_WETH = 10;

    address private constant _PRINCIPAL_TOKEN_ADDRESS_ETH = address(0);

    // General constants
    uint256 constant _TERMINAL_MAX_LOCK_DURATION = 157680000;
    uint256 private constant SECONDS_PER_YEAR = 31536000; // seconds in a 365 day year
    uint256 public maxLockDuration = 7776000; // 7776000 starting value for maximum allowed lock duration of user´s balance in seconds (90 days)
    uint256 private constant OWNER_DURATION = 31536000; // 1 Year

    // Portal Constructor values
    uint256 constant _TARGET_CONSTANT_USDC = 440528634361 * 1e36;
    uint256 constant _TARGET_CONSTANT_WETH = 125714213 * 1e36;

    uint256 constant _FUNDING_PHASE_DURATION = 604800; // 7 days
    uint256 constant _FUNDING_MIN_AMOUNT = 1e25; // 10M PSM

    uint256 constant _DECIMALS = 18;
    uint256 constant _DECIMALS_USDC = 6;

    uint256 constant _AMOUNT_TO_CONVERT = 100000 * 1e18;

    string _META_DATA_URI = "abcd";

    // time
    uint256 timestamp;
    uint256 fundingPhase;
    uint256 ownerExpiry;
    uint256 hundredYearsLater;

    // prank addresses

    address public Alice2;
    address public Bob2;
    address public Karen2;

    address payable Alice;
    address payable Bob;
    address payable Karen;

    // Token Instances
    MockToken psm ;
    MockToken usdc ;
    MockToken weth;
    MockToken esVKA;
    MockToken hbToken;

    EthWater USDC_WATER;
    EthWater WETH_WATER;

    FiatTokenV2_2 _PRINCIPAL_TOKEN_ADDRESS_USDC;
    HandlerVirtual handlerVirtual;

    // Portals & LP
    PortalV2MultiAsset public portal_USDC;
    PortalV2MultiAsset public portal_ETH;
    VirtualLP public virtualLP;

    // Simulated USDC distributor
    address public usdcSender;

    // PSM Treasury
    address public psmSender;

    // starting token amounts
    uint256 usdcAmount = 1e12; // 1M USDC
    uint256 psmAmount = 1e25; // 10M PSM
    uint256 usdcSendAmount = 1e9; // 1k USDC

    uint256 public constant FUNDING_MAX_RETURN_PERCENT = 1000;
    uint256 public _DENOMINATOR = 31536000000000;

    ////////////// SETUP ////////////////////////
    function setUp() public {
        Alice2 = svm.createAddress("Alice2");
        Bob2 = svm.createAddress("Bob2");
        Karen2 = svm.createAddress("Karen2");
        usdcSender = svm.createAddress("usdcSender");
        psmSender = svm.createAddress("psmSender");
        
        Alice = payable(Alice2);
        Bob = payable(Bob2);
        Karen = payable(Karen2);

        psm = new MockToken("psm","psm");
        usdc = new MockToken("usdc","usdc");
        weth = new MockToken("weth", "weth");
        esVKA = new MockToken("esVKA", "esVKA");
        hbToken = new MockToken("hbToken", "hbToken");

        USDC_WATER = new EthWater();
        WETH_WATER = new EthWater();
        _PRINCIPAL_TOKEN_ADDRESS_USDC = new FiatTokenV2_2();
        handlerVirtual = new HandlerVirtual(psmSender,_FUNDING_MIN_AMOUNT);



        // Create Virtual LP instance
        virtualLP = new VirtualLP(
            psmSender,
            _AMOUNT_TO_CONVERT,
            _FUNDING_PHASE_DURATION,
            _FUNDING_MIN_AMOUNT
        );
        // address _VIRTUAL_LP = address(virtualLP);

        // Create Portal instances
        portal_USDC = new PortalV2MultiAsset(
            address(virtualLP),
            _TARGET_CONSTANT_USDC,
            address(_PRINCIPAL_TOKEN_ADDRESS_USDC),
            _DECIMALS_USDC,
            "USD Coin",
            "USDC",
            _META_DATA_URI
        );
        portal_ETH = new PortalV2MultiAsset(
            address(virtualLP),
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
        uint256 mintAmount = 1e65; 

        vm.prank(psmSender);
        psm.mint(psmSender, mintAmount);
        
        vm.startPrank(psmSender);
        psm.approve(address(virtualLP), mintAmount);
        psm.approve(address(handlerVirtual), mintAmount);
        vm.stopPrank();

        vm.prank(usdcSender);
        usdc.mint(usdcSender, mintAmount);


        uint256 transferAmountAlice = 1e25;
        uint256 transferAmountBob = 1e24; 
        uint256 transferAmountKaren = 1e23; 

        vm.prank(psmSender);
        psm.transfer(Alice, transferAmountAlice);
        vm.prank(usdcSender);
        usdc.transfer(Alice, transferAmountAlice);

        vm.prank(psmSender);
        psm.transfer(Bob, transferAmountBob);
        vm.prank(usdcSender);
        usdc.transfer(Bob, transferAmountBob);

        vm.prank(psmSender);
        psm.transfer(Karen, transferAmountKaren);
        vm.prank(usdcSender);
        usdc.transfer(Karen, transferAmountKaren);

        uint256 etherAmount = 1e65;

        vm.deal(Alice, etherAmount);
        vm.deal(Bob, etherAmount);
        vm.deal(Karen, etherAmount);

        vm.deal(address(psm), etherAmount);
        vm.deal(address(usdc), etherAmount);
        vm.deal(address(virtualLP), etherAmount);
        vm.deal(address(handlerVirtual), etherAmount);
    } 



        // ============================================
        // ==               FV                       ==
        // ============================================


    
/////////////////////////////////////////////////

//                  VirtualLP                  //

/////////////////////////////////////////////////


////////////// check_getBurnValuePSM //////////////
    function check_getBurnValuePSM(uint256 _amount) public {

        vm.assume(_amount > 0 && _amount <= 1e24);
        // uint32 _amount = uint32(svm.createUint(amount, "amount"));

        uint256 burnValue = handlerVirtual._handler_getBurnValuePSM(_amount);

        uint256 minValue = (_amount * 100) / FUNDING_MAX_RETURN_PERCENT;
        uint256 accruedValue = (_amount * (block.timestamp - handlerVirtual.CREATION_TIME()) * handlerVirtual.FUNDING_APR()) / (100 * SECONDS_PER_YEAR);
        uint256 maxValue = _amount;
        uint256 currentValue = minValue + accruedValue;
        uint256 burnValue2 = (currentValue < maxValue) ? currentValue : maxValue;


        uint256 timeFactor = (block.timestamp - handlerVirtual.CREATION_TIME()) * handlerVirtual.FUNDING_APR();
        uint256 accruedValue2 = _amount * timeFactor / (100 * SECONDS_PER_YEAR);

        assert(burnValue == burnValue2);
        assert(accruedValue == (currentValue - minValue ) );
        assert(accruedValue == accruedValue2);

    }

////////////// test_BurnValue_Within_Min_Max //////////////

    function check_BurnValue_Within_Min_Max(uint256 _amount) public {
        vm.assume(_amount > 0 && _amount <= 1e24);

        uint256 burnValue = handlerVirtual._handler_getBurnValuePSM(_amount);
        uint256 minValue = (_amount * 100) / handlerVirtual.FUNDING_MAX_RETURN_PERCENT();
        uint256 maxValue = _amount;

        assert(burnValue >= minValue);
        assert(burnValue <= maxValue);    
    }

////////////// test_Calculation_Logic_of_BurnValue //////////////

    function check_Calculation_Logic_of_BurnValue(uint256 _amount) public {
        vm.assume(_amount > 0 && _amount <= 1e24);

        uint256 burnValue = handlerVirtual._handler_getBurnValuePSM(_amount);

        uint256 minValue = (_amount * 100) / handlerVirtual.FUNDING_MAX_RETURN_PERCENT();
        uint256 timeFactor = (block.timestamp - handlerVirtual.CREATION_TIME()) * handlerVirtual.FUNDING_APR();
        uint256 accruedValue = _amount * timeFactor / (100 * SECONDS_PER_YEAR);
        
        uint256 currentValue = minValue + accruedValue;
        uint256 expectedBurnValue = (currentValue < _amount) ? currentValue : _amount;

        assert(burnValue == expectedBurnValue);
    }

////////////// test_BurnValue_Changes_Over_Time //////////////

    function check_BurnValue_Changes_Over_Time(uint256 _amount) public {
        vm.assume(_amount > 0 && _amount <= 1e24);

        uint256 initialBurnValue = handlerVirtual._handler_getBurnValuePSM(_amount);
        uint256 timeToWarp = 31536000; // 365 días expresados en segundos
        vm.warp(block.timestamp + timeToWarp);

        uint256 newBurnValue = handlerVirtual._handler_getBurnValuePSM(_amount);
        assertTrue(newBurnValue >= initialBurnValue);
    }

////////////// check_BurnValue_BlockTimestamp_Changes_Over_Time //////////////

    function check_BurnValue_BlockTimestamp_Changes_Over_Time(uint256 _amount) public { //@audit
        vm.assume(_amount > 0 && _amount <= 1e24);

        uint256 initialBurnValue = handlerVirtual._handler_getBurnValuePSM(_amount);
        console2.log("initialBurnValue",initialBurnValue);

        uint256 timeToWarp = 31536000;
        vm.warp(block.timestamp + 365 days);

        uint256 YearnewBurnValue = handlerVirtual._handler_getBurnValuePSM(_amount);
        console2.log("YearnewBurnValue",YearnewBurnValue);
  
        uint256 YearRate = YearnewBurnValue - initialBurnValue;
        console2.log("YearRate",YearRate);

        // 1 week
        uint256 weekRate = ((7 days * YearRate) / 365 days);
        console2.log("weekRate",weekRate);

        vm.warp(block.timestamp + 7 days);

        uint256 WeakBurnValue = handlerVirtual._handler_getBurnValuePSM(_amount);
        console2.log("WeakBurnValue",WeakBurnValue);

    
        assert(WeakBurnValue == (YearnewBurnValue + weekRate ));
        assert(YearnewBurnValue == initialBurnValue + YearRate);

    }


/////////////////////////////////////////////////

//              PORTALVIRTUALV2                //

/////////////////////////////////////////////////


////////////// check_BurnableBTokenAmountLogic //////////////

function check_BurnableBTokenAmountLogic(uint256 fundingRewardPool) public {
        vm.assume(fundingRewardPool > 0 && fundingRewardPool <= 1e24);

        uint256 burnValueFor1e18 = handlerVirtual._handler_getBurnValuePSM(1e18) + 1;
        uint256 expectedAmountBurnable = (fundingRewardPool * 1e18) / burnValueFor1e18;
        uint256 actualAmountBurnable = handlerVirtual._handler_Modify_getBurnableBtokenAmount(fundingRewardPool);

        assert (actualAmountBurnable == expectedAmountBurnable);
}


////////////// check_BurnableBTokenAmount_Changes_Over_Time //////////////
function check_BurnableBTokenAmount_Changes_Over_Time(uint256 fundingRewardPool) public {
    vm.assume(fundingRewardPool > 0 && fundingRewardPool <= 1e24);

    uint256 initialAmountBurnable = handlerVirtual._handler_Modify_getBurnableBtokenAmount(fundingRewardPool);
    uint256 timeToWarp = 365 days; // Ajuste según sea necesario
    vm.warp(block.timestamp + timeToWarp);

    uint256 newAmountBurnable = handlerVirtual._handler_Modify_getBurnableBtokenAmount(fundingRewardPool);

    assertTrue(newAmountBurnable <= initialAmountBurnable);
}



////////////// check_stake //////////////

    function check_stake() public {
        uint256 stakeAmount = 1000e18; // Simplified stake amount
        vm.prank(Alice);
        portal_ETH.stake(stakeAmount);
        vm.prank(Alice);
        portal_ETH.unstake(stakeAmount);

        // Assertion to ensure total staked balance is correct
        assert(portal_ETH.totalPrincipalStaked() == 0);
    }


////////////// check_Incariant_Stake //////////////
    function check_Incariant_Stake(bytes4 selector, bytes memory args) public virtual {
        uint256 stakeAmount = 1000e18;
        bytes memory args = svm.createBytes(1024, 'data');

        uint256 oldBalanceOther = portal_ETH.totalPrincipalStaked();
        vm.prank(Alice);
        portal_ETH.stake(stakeAmount);

        vm.prank(Alice);
        (bool success,) = address(portal_ETH).call(abi.encodePacked(selector, args));
        
        vm.assume(success);
        vm.prank(Alice);
        portal_ETH.unstake(stakeAmount);

        uint256 oldBalanceOther2 = portal_ETH.totalPrincipalStaked();

        assert(oldBalanceOther == oldBalanceOther2);
       
    }


////////////// check_PortalEnergy_TimeAndLockChange //////////////
    function check_PortalEnergy_TimeAndLockChange(uint256 _amount, uint256 _lastUpdateTime ) public {
    
        vm.assume(_amount > 0 && _amount <= 1e24);
        vm.assume(_lastUpdateTime <= block.timestamp);
        uint256 _portalEnergy = 500;
        uint256 _User_maxLockDuration = 7776000 - (5000);
        uint256 _stakeBalance = 100;



        uint256 amount = _amount; 
        bool isPositive = true; 
        uint256 portalEnergyNetChange;
        uint256 timePassed = block.timestamp - _lastUpdateTime;
        uint256 maxLockDifference = maxLockDuration - _User_maxLockDuration;
        uint256 adjustedPE = amount * maxLockDuration * 1e18;
        uint256 stakedBalance = _stakeBalance; 

        if (_lastUpdateTime > 0) {
                
                uint256 portalEnergyEarned = stakedBalance * timePassed;

                uint256 portalEnergyIncrease = stakedBalance * maxLockDifference;

                portalEnergyNetChange =((portalEnergyEarned + portalEnergyIncrease) * 1e18) / _DENOMINATOR;
            }


        assertTrue(portalEnergyNetChange >= 0, "Portal energy net change should be non-negative");

        uint256 newTimePassed = timePassed + 1 days;
        uint256 newPortalEnergyNetChange = ((stakedBalance * newTimePassed + stakedBalance * maxLockDifference) * 1e18) / _DENOMINATOR;
        assertTrue(newPortalEnergyNetChange > portalEnergyNetChange, "Portal energy should increase with time");

        if (timePassed == 0 && maxLockDifference == 0) {
            assertEq(portalEnergyNetChange, 0, "Portal energy net change should be zero when no time has passed and no max lock duration change");
        }
    }



////////////// check_PortalEnergyImpactOnTimeAndLock //////////////

    function check_PortalEnergyImpactOnTimeAndLock(
        uint256 _amount,
        uint256 _lastUpdateTime
    ) public {
        vm.assume(_amount > 0 && _amount <= 1e24);
        vm.assume(_lastUpdateTime <= block.timestamp);

        uint256 _portalEnergy = 500;
        uint256 _User_maxLockDuration = 7776000 - 5000;
        uint256 _stakeBalance = 100;
        bool isPositive = true;
        uint256 timePassed = block.timestamp - _lastUpdateTime;
        uint256 maxLockDifference = maxLockDuration - _User_maxLockDuration;

        uint256 portalEnergyNetChange = calculatePortalEnergyNetChange(
            _stakeBalance,
            timePassed,
            maxLockDifference
        );

        uint256 portalEnergyAdjustment = calculatePortalEnergyAdjustment(_amount);

        uint256 portalEnergyTokensRequired = calculatePortalEnergyTokensRequired(
            isPositive,
            portalEnergyAdjustment,
            _portalEnergy,
            portalEnergyNetChange
        );

        uint256 stakedBalanceUpdated = updateStakedBalance(
            _stakeBalance,
            _amount,
            isPositive
        );

        assert(portalEnergyNetChange >= 0 );
        assert(portalEnergyAdjustment >= 0);

        if (isPositive) {
            assert(stakedBalanceUpdated >= _stakeBalance);
        } else {
            assert(stakedBalanceUpdated <= _stakeBalance);
        }

        assert(portalEnergyTokensRequired >= 0);

        assert(_lastUpdateTime <= block.timestamp);

    }


    ////////////// check_DetailedPortalEnergyTimeLockAdjustments //////////////

    function check_DetailedPortalEnergyTimeLockAdjustments(uint256 _amount, uint256 _lastUpdateTime) public {
        vm.assume(_amount > 0 && _amount <= 1e24);
        vm.assume(_lastUpdateTime <= block.timestamp);

        uint256 initialPortalEnergy = 500;
        uint256 userMaxLockDuration = 7776000 - 5000;
        uint256 stakeBalance = 100;

        uint256 timePassed = block.timestamp - _lastUpdateTime;
        uint256 maxLockDifference = maxLockDuration - userMaxLockDuration;
        uint256 adjustedPE = _amount * maxLockDuration * 1e18 / _DENOMINATOR;

        uint256 portalEnergyNetChange = ((stakeBalance * timePassed + stakeBalance * maxLockDifference) * 1e18) / _DENOMINATOR;
        uint256 newPortalEnergy = initialPortalEnergy + portalEnergyNetChange + adjustedPE;

        uint256 portalEnergyTokensRequired = (adjustedPE > initialPortalEnergy + portalEnergyNetChange) ? adjustedPE - (initialPortalEnergy + portalEnergyNetChange) : 0;

        uint256 stakedBalanceUpdated = stakeBalance + _amount;
        uint256 maxStakeDebt = (stakedBalanceUpdated * maxLockDuration * 1e18) / _DENOMINATOR;
        uint256 availableToWithdraw = (newPortalEnergy >= maxStakeDebt) ? stakedBalanceUpdated : (stakedBalanceUpdated * newPortalEnergy) / maxStakeDebt;

        assertTrue(portalEnergyNetChange >= 0, "Net change in portal energy should be non-negative");
        assertGt(newPortalEnergy, initialPortalEnergy, "New portal energy should be greater than initial");
        assertTrue(stakedBalanceUpdated > stakeBalance, "Staked balance should increase");
        assertTrue(maxStakeDebt >= 0, "Max stake debt should be non-negative");
        assertTrue(availableToWithdraw <= stakedBalanceUpdated, "Available to withdraw should not exceed updated staked balance");

        if (newPortalEnergy >= maxStakeDebt) {
            assertEq(availableToWithdraw, stakedBalanceUpdated, "Available to withdraw should match updated staked balance when portal energy exceeds max stake debt");
        } else {
            assertLt(availableToWithdraw, stakedBalanceUpdated, "Available to withdraw should be less than updated staked balance when portal energy is less than max stake debt");
        }
    }



    ////////////// check_PortalEnergyAdjustmentNegativeImpact //////////////
    function check_PortalEnergyAdjustmentNegativeImpact(
        uint256 _amount,
        uint256 _lastUpdateTime
    ) public {
        vm.assume(_amount > 0 && _amount <= 1e24);
        vm.assume(_lastUpdateTime <= block.timestamp);

        uint256 _portalEnergy = 500;
        uint256 _User_maxLockDuration = 7776000 - 5000;
        uint256 _stakeBalance = _amount + 500;
        bool isPositive = false; 
        uint256 timePassed = block.timestamp - _lastUpdateTime;
        uint256 maxLockDifference = maxLockDuration - _User_maxLockDuration;

        uint256 portalEnergyNetChange = calculatePortalEnergyNetChange(
                _stakeBalance,
                timePassed,
                maxLockDifference
            );

            uint256 portalEnergyAdjustment = calculatePortalEnergyAdjustment(_amount);

            uint256 portalEnergyTokensRequired = calculatePortalEnergyTokensRequired(
                isPositive,
                portalEnergyAdjustment,
                _portalEnergy,
                portalEnergyNetChange
            );

            uint256 stakedBalanceUpdated = updateStakedBalance(
                _stakeBalance,
                _amount,
                isPositive
            );

            assert(portalEnergyNetChange >= 0);

            assert(portalEnergyAdjustment > 0);

            if (portalEnergyAdjustment > (_portalEnergy + portalEnergyNetChange)) {
                assert(portalEnergyTokensRequired > 0);
            } else {
                assert(portalEnergyTokensRequired == 0);
            }

            assert(stakedBalanceUpdated < _stakeBalance);

        }   



    // ============================================
    // ==             HELPER ACTIONS             ==
    // ============================================

    function calculatePortalEnergyNetChange(
        uint256 stakedBalance,
        uint256 timePassed,
        uint256 maxLockDifference
    ) private view returns (uint256) {
        uint256 portalEnergyEarned = stakedBalance * timePassed;
        uint256 portalEnergyIncrease = stakedBalance * maxLockDifference;
        return (portalEnergyEarned + portalEnergyIncrease) * 1e18 / _DENOMINATOR;
    }

    function calculatePortalEnergyAdjustment(
        uint256 amount
    ) private view returns (uint256) {
        return amount * maxLockDuration * 1e18 / _DENOMINATOR;
    }

    function updateStakedBalance(
        uint256 stakedBalance,
        uint256 amount,
        bool isPositive
    ) private pure returns (uint256) {
        return isPositive ? stakedBalance + amount : stakedBalance - amount;
    }

    function calculatePortalEnergyTokensRequired(
        bool isPositive,
        uint256 portalEnergyAdjustment,
        uint256 portalEnergy,
        uint256 portalEnergyNetChange
    ) private pure returns (uint256) {
        if (!isPositive && portalEnergyAdjustment > (portalEnergy + portalEnergyNetChange)) {
            return portalEnergyAdjustment - (portalEnergy + portalEnergyNetChange);
        } else {
            return 0;
        }
    }



   
}