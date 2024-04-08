// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {PortalV2MultiAsset} from "src/V2MultiAsset/PortalV2MultiAsset.sol";
import {MintBurnToken} from "src/V2MultiAsset/MintBurnToken.sol";
import {VirtualLP} from "src/V2MultiAsset/VirtualLP.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWater} from "src/V2MultiAsset/interfaces/IWater.sol";
import {ISingleStaking} from "src/V2MultiAsset/interfaces/ISingleStaking.sol";
import {IDualStaking} from "src/V2MultiAsset/interfaces/IDualStaking.sol";
import {IPortalV2MultiAsset} from "src/V2MultiAsset/interfaces/IPortalV2MultiAsset.sol";

import{MockToken} from "./mocks/MockToken.sol";

import {SingleStakingV2} from "src/onchain/SingleStakingV2.sol";
import {EthWater} from "src/onchain/Water.sol";
import {FiatTokenV2_2} from "src/onchain/FiatTokenV2_2.sol";
import {esVKAToken} from "src/onchain/esVKAToken.sol";

import {HandlerVirtual} from "./handlerVirtual.sol";
import {HandlerPortalV2} from "./handlerPortalV2.t.sol";


contract ZealynxTest is Test {


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
    address payable Alice = payable(0x46340b20830761efd32832A74d7169B29FEB9758);
    address payable Bob = payable(0xDD56CFdDB0002f4d7f8CC0563FD489971899cb79);
    address payable Karen = payable(0x3A30aaf1189E830b02416fb8C513373C659ed748);

    // Token Instances
    MockToken psm ;
    MockToken usdc ;
    MockToken weth;
    // MockToken esVKA;
    MockToken hbToken;

    EthWater USDC_WATER;
    EthWater WETH_WATER;

    FiatTokenV2_2 _PRINCIPAL_TOKEN_ADDRESS_USDC;
    HandlerVirtual handlerVirtual;
    HandlerPortalV2 handlerPortalV2;

    esVKAToken esVKA ;

    // Portals & LP
    PortalV2MultiAsset public portal_USDC;
    PortalV2MultiAsset public portal_ETH;
    VirtualLP public virtualLP;

    // Simulated USDC distributor
    address usdcSender = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    // PSM Treasury
    address psmSender = 0xAb845D09933f52af5642FC87Dd8FBbf553fd7B33;

    // starting token amounts
    uint256 usdcAmount = 1e12; // 1M USDC
    uint256 psmAmount = 1e25; // 10M PSM
    uint256 usdcSendAmount = 1e9; // 1k USDC


    uint256 public constant FUNDING_MAX_RETURN_PERCENT = 1000;

    ////////////// SETUP ////////////////////////
    function setUp() public {
        psm = new MockToken("psm","psm");
        usdc = new MockToken("usdc","usdc");
        weth = new MockToken("weth", "weth");
        hbToken = new MockToken("hbToken", "hbToken");
        esVKA = new esVKAToken();

        USDC_WATER = new EthWater();
        WETH_WATER = new EthWater();
        _PRINCIPAL_TOKEN_ADDRESS_USDC = new FiatTokenV2_2();

        //Handler
        handlerVirtual = new HandlerVirtual(psmSender,_FUNDING_MIN_AMOUNT);

        // Create Virtual LP instance
       virtualLP = new VirtualLP(
            psmSender,
            _AMOUNT_TO_CONVERT,
            _FUNDING_PHASE_DURATION,
            _FUNDING_MIN_AMOUNT
        );
        // address _VIRTUAL_LP = address(virtualLP);
        handlerPortalV2 = new HandlerPortalV2(_FUNDING_MIN_AMOUNT, address(virtualLP), address(_PRINCIPAL_TOKEN_ADDRESS_USDC));

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

        // Mintear tokens PSM a psmSender
        vm.prank(psmSender);
        psm.mint(psmSender, mintAmount);
        
        vm.startPrank(psmSender);
        psm.approve(address(virtualLP), mintAmount);
        psm.approve(address(handlerVirtual), mintAmount);
        vm.stopPrank();

        vm.prank(Alice);
        psm.approve(address(handlerVirtual), mintAmount);
        
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
        vm.deal(address(this), etherAmount);
    }

    // ============================================
    // ==             FV                         ==
    // ============================================



/////////////////////////////////////////////////

//                  VirtualLP                  //

/////////////////////////////////////////////////

////////////// test_getBurnValuePSM //////////////

    function test_getBurnValuePSM(uint256 _amount) public {
        vm.assume(_amount > 0 && _amount <= 1e24);

        uint256 burnValue = handlerVirtual._handler_getBurnValuePSM(_amount);

        uint256 minValue = (_amount * 100) / FUNDING_MAX_RETURN_PERCENT;
        uint256 accruedValue = (_amount * (block.timestamp - handlerVirtual.CREATION_TIME()) * handlerVirtual.FUNDING_APR()) / (100 * SECONDS_PER_YEAR);
        uint256 maxValue = _amount;
        uint256 currentValue = minValue + accruedValue;

        uint256 burnValueLocal = (currentValue < maxValue) ? currentValue : maxValue;


        uint256 timeFactor = (block.timestamp - handlerVirtual.CREATION_TIME()) * handlerVirtual.FUNDING_APR();
        uint256 accruedValueLocal = _amount * timeFactor / (100 * SECONDS_PER_YEAR);

        assert(burnValue == burnValueLocal);
        assert(accruedValue == (currentValue - minValue ) );
        assert(accruedValue == accruedValueLocal);

    }


////////////// test_BurnValue_Within_Min_Max //////////////
    function test_BurnValue_Within_Min_Max(uint256 _amount) public {
        vm.assume(_amount > 0 && _amount <= 1e24);

        uint256 burnValue = handlerVirtual._handler_getBurnValuePSM(_amount);
        uint256 minValue = (_amount * 100) / handlerVirtual.FUNDING_MAX_RETURN_PERCENT();
        uint256 maxValue = _amount;

        assert(burnValue >= minValue);
        assert(burnValue <= maxValue);
    }

////////////// test_Calculation_Logic_of_BurnValue //////////////
    function test_Calculation_Logic_of_BurnValue(uint256 _amount) public {
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

    function test_BurnValue_Changes_Over_Time(uint256 _amount) public {
        vm.assume(_amount > 0 && _amount <= 1e24);

        uint256 initialBurnValue = handlerVirtual._handler_getBurnValuePSM(_amount);
        console2.log(initialBurnValue);
        uint256 timeToWarp = 31536000; // 365 días expresados en segundos
        vm.warp(block.timestamp + timeToWarp);

        uint256 newBurnValue = handlerVirtual._handler_getBurnValuePSM(_amount);
        console2.log(newBurnValue);
        assertTrue(newBurnValue >= initialBurnValue);
    }

////////////// test_BurnValue_BlockTimestamp_Changes_Over_Time //////////////

    function test_BurnValue_BlockTimestamp_Changes_Over_Time(uint256 _amount) public { //@audit
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


////////////// test_BurnableBTokenAmountLogic //////////////

    function test_BurnableBTokenAmountLogic(uint256 fundingRewardPool) public { 
        vm.assume(fundingRewardPool > 0 && fundingRewardPool <= 1e24);

        uint256 burnValueFor1e18 = handlerVirtual._handler_getBurnValuePSM(1e18) + 1;
        uint256 expectedAmountBurnable = (fundingRewardPool * 1e18) / burnValueFor1e18;
        uint256 actualAmountBurnable = handlerVirtual._handler_Modify_getBurnableBtokenAmount(fundingRewardPool);

        assert (actualAmountBurnable == expectedAmountBurnable);
    }


    ////////////// test_BurnableBTokenAmount_Changes_Over_Time //////////////
    function test_BurnableBTokenAmount_Changes_Over_Time(uint256 fundingRewardPool) public {
        vm.assume(fundingRewardPool > 0 && fundingRewardPool <= 1e24);

        uint256 initialAmountBurnable = handlerVirtual._handler_Modify_getBurnableBtokenAmount(fundingRewardPool);
        uint256 timeToWarp = 365 days; 
        vm.warp(block.timestamp + timeToWarp);

        uint256 newAmountBurnable = handlerVirtual._handler_Modify_getBurnableBtokenAmount(fundingRewardPool);

        assertTrue(newAmountBurnable <= initialAmountBurnable);
    }





function test_HandlerBurnBtokens(uint256 _amountToBurn, uint256 _burnable) public { //@audit
    vm.assume(_amountToBurn > 0 && _amountToBurn <= 1e24);
    vm.assume(_burnable > 0 && _burnable < _amountToBurn);

    address hbTokenAddress = address(hbToken);
    address psmAddress = address(psm);

    uint256 initialHBTokenBalance = _amountToBurn + 1e18; 
    uint256 initialPSMBalance = handlerVirtual._handler_getBurnValuePSM(_amountToBurn) + 1e18; 

    hbToken.mint(address(Alice), initialHBTokenBalance);
    psm.mint(address(handlerVirtual), initialPSMBalance);

    // Alice aprueba al handlerVirtual para quemar sus tokens
    vm.startPrank(address(Alice)); 
    hbToken.approve(address(handlerVirtual), _amountToBurn);
    vm.stopPrank();

    // Capturamos balances iniciales para validación posterior
    uint256 initialSenderPSMBalance = psm.balanceOf(address(Alice));
    uint256 initialContractHBTokenBalance = hbToken.balanceOf(address(handlerVirtual));

    // Logs para depuración
    console2.log("Allowance before burn:", hbToken.allowance(address(Alice), address(handlerVirtual)));
    console2.log("Alice HBToken balance before burn:", hbToken.balanceOf(address(Alice)));

    // Realizamos la operación de quemar bTokens como Alice
    vm.prank(address(Alice)); 
    handlerVirtual._handler_Modify_burnBtokens(_amountToBurn, hbTokenAddress, psmAddress, _burnable);

    // Validamos las condiciones posteriores
    uint256 finalSenderPSMBalance = psm.balanceOf(address(Alice));
    uint256 finalContractHBTokenBalance = hbToken.balanceOf(address(handlerVirtual));
    uint256 amountReceived = finalSenderPSMBalance - initialSenderPSMBalance;

    // Aseguramos que los bTokens fueron quemados correctamente
    assertTrue(finalContractHBTokenBalance == initialContractHBTokenBalance - _amountToBurn, "bTokens not burned properly");

    // Verificamos que el usuario (Alice) recibió la cantidad adecuada de PSM
    assertTrue(amountReceived > 0, "PSM not received");
    assertTrue(amountReceived == handlerVirtual._handler_getBurnValuePSM(_amountToBurn), "Incorrect PSM amount received");
}




/////////////////////////////////////////////////

    ///////// PORTALVIRTUALV2 //////////////

/////////////////////////////////////////////////


    uint256 public _DENOMINATOR = 31536000000000;


    function test_PortalEnergy_TimeAndLockChange(uint256 _amount, uint256 _lastUpdateTime ) public {
    
        vm.assume(_amount > 0 && _amount <= 1e24);
        vm.assume(_lastUpdateTime <= block.timestamp);
        uint256 _portalEnergy = 500;
        uint256 _User_maxLockDuration = 7776000 - (5000);
        uint256 _stakeBalance = 100;



        uint256 amount = _amount; // to avoid stack too deep issue
        bool isPositive = true; // to avoid stack too deep issue
        uint256 portalEnergyNetChange;
        uint256 timePassed = block.timestamp - _lastUpdateTime;
        uint256 maxLockDifference = maxLockDuration - _User_maxLockDuration;
        uint256 adjustedPE = amount * maxLockDuration * 1e18;
        uint256 stakedBalance = _stakeBalance; 

        if (_lastUpdateTime > 0) {
                /// @dev Calculate the Portal Energy earned since the last update
                uint256 portalEnergyEarned = stakedBalance * timePassed;

                /// @dev Calculate the gain of Portal Energy from maxLockDuration increase
                uint256 portalEnergyIncrease = stakedBalance * maxLockDifference;

                /// @dev Summarize Portal Energy changes and divide by common denominator
                portalEnergyNetChange =((portalEnergyEarned + portalEnergyIncrease) * 1e18) / _DENOMINATOR;
            }


        // Aserciones
        assertTrue(portalEnergyNetChange >= 0, "Portal energy net change should be non-negative");

        uint256 newTimePassed = timePassed + 1 days; // Simula un día más
        uint256 newPortalEnergyNetChange = ((stakedBalance * newTimePassed + stakedBalance * maxLockDifference) * 1e18) / _DENOMINATOR;
        assertTrue(newPortalEnergyNetChange > portalEnergyNetChange, "Portal energy should increase with time");

        if (timePassed == 0 && maxLockDifference == 0) {
            assertEq(portalEnergyNetChange, 0, "Portal energy net change should be zero when no time has passed and no max lock duration change");
        }
    }




    function test_3PortalEnergy_TimeAndLockChange(uint256 _amount, uint256 _lastUpdateTime) public {
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

    function test_2PortalEnergy_TimeAndLockChange(
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

    ////////////// test_4PortalEnergy_TimeAndLockChange_Negative //////////////

    function test_4PortalEnergy_TimeAndLockChange_Negative(
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
    ) private pure returns (uint256 updatedBalance) {
        if (isPositive) {
            updatedBalance = stakedBalance + amount;
        } else {
            require(stakedBalance >= amount, "Insufficient staked balance for withdrawal");
            updatedBalance = stakedBalance - amount;
        }
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