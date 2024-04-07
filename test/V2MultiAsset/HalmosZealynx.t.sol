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

import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {HandlerVirtual} from "./handlerVirtual.sol";



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
    // address usdcSender = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
    address public usdcSender;


    // PSM Treasury
    // address psmSender = 0xAb845D09933f52af5642FC87Dd8FBbf553fd7B33;
    address public psmSender;

    // starting token amounts
    uint256 usdcAmount = 1e12; // 1M USDC
    uint256 psmAmount = 1e25; // 10M PSM
    uint256 usdcSendAmount = 1e9; // 1k USDC

    uint256 public constant FUNDING_MAX_RETURN_PERCENT = 1000;

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

        // Mintear tokens PSM a psmSender
        vm.prank(psmSender);
        psm.mint(psmSender, mintAmount);
        
        vm.startPrank(psmSender);
        psm.approve(address(virtualLP), mintAmount);
        psm.approve(address(handlerVirtual), mintAmount);
        vm.stopPrank();

        // Mintear tokens USDC a usdcSender
        vm.prank(usdcSender);
        usdc.mint(usdcSender, mintAmount);


        uint256 transferAmountAlice = 1e25;
        uint256 transferAmountBob = 1e24; 
        uint256 transferAmountKaren = 1e23; 

        // Transferir PSM a Alice
        vm.prank(psmSender);
        psm.transfer(Alice, transferAmountAlice);
        // Transferir USDC a Alice
        vm.prank(usdcSender);
        usdc.transfer(Alice, transferAmountAlice);

        // Transferir PSM a Bob
        vm.prank(psmSender);
        psm.transfer(Bob, transferAmountBob);
        // Transferir USDC a Bob
        vm.prank(usdcSender);
        usdc.transfer(Bob, transferAmountBob);

        // Transferir PSM a Karen
        vm.prank(psmSender);
        psm.transfer(Karen, transferAmountKaren);
        // Transferir USDC a Karen
        vm.prank(usdcSender);
        usdc.transfer(Karen, transferAmountKaren);

        // Además, si necesitas asegurar que Alice, Bob, y Karen tengan ETH para interactuar con la blockchain:
        uint256 etherAmount = 1e65; // Cantidad de Ether para transferir, por ejemplo, 10 Ether

        // Proporcionar Ether a Alice, Bob, y Karen
        vm.deal(Alice, etherAmount);
        vm.deal(Bob, etherAmount);
        vm.deal(Karen, etherAmount);

        // Finalmente, asegúrate de que las direcciones de los contratos también tengan ETH si es necesario
        vm.deal(address(psm), etherAmount);
        vm.deal(address(usdc), etherAmount);
        vm.deal(address(virtualLP), etherAmount);
        vm.deal(address(handlerVirtual), etherAmount);
    } 


    //////////// testSuccess_buyPortalEnergy ////////////

    function check_testSuccess_buyPortalEnergy() public { 
        console2.log("codesize");

        vm.startPrank(psmSender);
        psm.approve(address(virtualLP), 1e55);
        handlerVirtual._contributeFunding(_FUNDING_MIN_AMOUNT, address(psm), address(hbToken));
        vm.stopPrank();

        vm.prank(psmSender);
        virtualLP.registerPortal(
            address(portal_ETH),
            _PRINCIPAL_TOKEN_ADDRESS_ETH,
            address(WETH_WATER),
            _POOL_ID_WETH
        );
    }

    function check_testSuccess_buyPortalEnergy2() public { 
        console2.log("codesize");

        vm.startPrank(psmSender);
        psm.approve(address(virtualLP), 1e55);
        handlerVirtual._contributeFunding(_FUNDING_MIN_AMOUNT, address(psm), address(hbToken));
        vm.stopPrank();

        vm.prank(psmSender);
        virtualLP.registerPortal(
            address(portal_USDC),
            address(_PRINCIPAL_TOKEN_ADDRESS_USDC),
            address(USDC_WATER),
            _POOL_ID_USDC
        );
    }


////////////// FV //////////////

////////////// test_getburn //////////////
    function check_test_getburn(uint256 _amount) public {

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


/////////////////////////////////////////////////

    ///////// PORTALVIRTUALV2 //////////////

/////////////////////////////////////////////////


////////////// test_BurnableBTokenAmountLogic //////////////

function check_BurnableBTokenAmountLogic(uint256 fundingRewardPool) public {
        vm.assume(fundingRewardPool > 0 && fundingRewardPool <= 1e24);

        uint256 burnValueFor1e18 = handlerVirtual._handler_getBurnValuePSM(1e18) + 1;

        uint256 expectedAmountBurnable = (fundingRewardPool * 1e18) / burnValueFor1e18;

        uint256 actualAmountBurnable = handlerVirtual._handler_Modify_getBurnableBtokenAmount(fundingRewardPool);

        assert (actualAmountBurnable == expectedAmountBurnable);
}


////////////// test_BurnableBTokenAmount_Changes_Over_Time //////////////
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


////////////// _checkNoBackdoor //////////////
    function _checkNoBackdoor(bytes4 selector, bytes memory args) public virtual {
        // consider two arbitrary distinct accounts
        uint256 stakeAmount = 1000e18;
        bytes memory args = svm.createBytes(1024, 'data');

        // record their current balances
        uint256 oldBalanceOther = portal_ETH.totalPrincipalStaked();
        vm.prank(Alice);
        portal_ETH.stake(stakeAmount);

        // consider an arbitrary function call to the token from the caller
        vm.prank(Alice);
        (bool success,) = address(portal_ETH).call(abi.encodePacked(selector, args));
        
        vm.assume(success);
        vm.prank(Alice);
        portal_ETH.unstake(stakeAmount);

        uint256 oldBalanceOther2 = portal_ETH.totalPrincipalStaked();

        assert(oldBalanceOther == oldBalanceOther2);
       
    }

    uint256 public _DENOMINATOR = 31536000000000;

////////////// test_2change //////////////
    function test_PortalEnergy_TimeAndLockChange(uint256 _amount, uint256 _lastUpdateTime ) public {
    
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


        // Aserciones
        assertTrue(portalEnergyNetChange >= 0, "Portal energy net change should be non-negative");

        uint256 newTimePassed = timePassed + 1 days; // Simula un día más
        uint256 newPortalEnergyNetChange = ((stakedBalance * newTimePassed + stakedBalance * maxLockDifference) * 1e18) / _DENOMINATOR;
        assertTrue(newPortalEnergyNetChange > portalEnergyNetChange, "Portal energy should increase with time");

        if (timePassed == 0 && maxLockDifference == 0) {
            assertEq(portalEnergyNetChange, 0, "Portal energy net change should be zero when no time has passed and no max lock duration change");
        }
    }



////////////// test_2PortalEnergy_TimeAndLockChange //////////////

    function check_2PortalEnergy_TimeAndLockChange(
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


    ////////////// check_3PortalEnergy_TimeAndLockChange //////////////

    function check_3PortalEnergy_TimeAndLockChange(uint256 _amount, uint256 _lastUpdateTime) public {
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
////////////// HELPER FUNCTIONS /////////////

////////////// HELPER FUNCTIONS /////////////



    // function helper_Stake(address account, uint256 fuzzAmount) public {

    //  // STAKE //
    //     uint256 InitialUSDCBalance = usdc.balanceOf(account);

    //     // Aprobación y Stake
    //     vm.startPrank(account);
    //     usdc.approve(address(portal_USDC), fuzzAmount);
    //     portal_USDC.stake(fuzzAmount);
    //     vm.stopPrank();

    //     uint256 FinalUSDCBalance = usdc.balanceOf(account);

    //     // Verificaciones
    //     assertEq(InitialUSDCBalance - fuzzAmount, FinalUSDCBalance, "El balance de Alice despues del stake es incorrecto.");
    //     assertEq(portal_USDC.totalPrincipalStaked(), fuzzAmount, "El total principal staked no coincide con el monto de stake.");

    // }
    // create the bToken token
    function helper_create_bToken() public {
        virtualLP.create_bToken();
    }

    // fund the Virtual LP
    function helper_fundLP() public {
        vm.startPrank(psmSender);

        psm.approve(address(virtualLP), 1e55);
        virtualLP.contributeFunding(_FUNDING_MIN_AMOUNT);

        vm.stopPrank();
    }

    // Register USDC Portal
    function helper_registerPortalUSDC() public {
        vm.prank(psmSender);
        virtualLP.registerPortal(
            address(portal_USDC),
            address(_PRINCIPAL_TOKEN_ADDRESS_USDC),
            address(USDC_WATER),
            _POOL_ID_USDC
        );
    }

    // Register ETH Portal
    function helper_registerPortalETH() public {
        vm.prank(psmSender);
        virtualLP.registerPortal(
            address(portal_ETH),
            _PRINCIPAL_TOKEN_ADDRESS_ETH,
            address(WETH_WATER),
            _POOL_ID_WETH
        );
    }

    // activate the Virtual LP
    function helper_activateLP() public {
        vm.warp(fundingPhase);
        virtualLP.activateLP();
    }

    // fund and activate the LP and register both Portals
    function helper_prepareSystem() public {
        helper_create_bToken();
        helper_fundLP();
        helper_registerPortalETH();
        helper_registerPortalUSDC();
        helper_activateLP();
    }

    // // Deploy the NFT contract
    // function helper_createNFT() public {
    //     portal_USDC.create_portalNFT();
    // }

    // // Deploy the ERC20 contract for mintable Portal Energy
    // function helper_createPortalEnergyToken() public {
    //     portal_USDC.create_portalEnergyToken();
    // }

    // // Increase allowance of tokens used by the USDC Portal
    // function helper_setApprovalsInLP_USDC() public {
    //     virtualLP.increaseAllowanceDualStaking();
    //     virtualLP.increaseAllowanceSingleStaking(address(portal_USDC));
    //     virtualLP.increaseAllowanceVault(address(portal_USDC));
    // }

    // // Increase allowance of tokens used by the ETH Portal
    // function helper_setApprovalsInLP_ETH() public {
    //     virtualLP.increaseAllowanceDualStaking();
    //     virtualLP.increaseAllowanceSingleStaking(address(portal_ETH));
    //     virtualLP.increaseAllowanceVault(address(portal_ETH));
    // }

    // // send USDC to LP when balance is required
    // function helper_sendUSDCtoLP() public {
    //     vm.prank(usdcSender);
    //     usdc.transfer(address(virtualLP), usdcSendAmount); // Send 1k USDC to LP
    // }

    // // simulate a full convert() cycle
    // function helper_executeConvert() public {
    //     helper_sendUSDCtoLP();
    //     vm.startPrank(psmSender);
    //     psm.approve(address(virtualLP), 1e55);
    //     virtualLP.convert(
    //         address(_PRINCIPAL_TOKEN_ADDRESS_USDC),
    //         msg.sender,
    //         1,
    //         block.timestamp
    //     );
    //     vm.stopPrank();
    // }
}

