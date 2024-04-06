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
        handlerVirtual = new HandlerVirtual(psmSender,_AMOUNT_TO_CONVERT, _FUNDING_PHASE_DURATION,_FUNDING_MIN_AMOUNT);



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

    function check_testSuccess_buyPortalEnergy() public { 
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

    
// function check_testSuccess_buyPortalEnergy(uint256 fuzzAmount) public { // @audit-ok => FV
    //     helper_prepareSystem();

    //     uint256 portalEnergy;
    //     (, , , , portalEnergy, , ) = portal_USDC.getUpdateAccount(
    //         Alice,
    //         0,
    //         true
    //     );
    //     uint256 minOperationalAmount = 1e4; // Ejemplo de un mínimo operativo que considera las tarifas
    //     uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
    //     vm.assume(fuzzAmount >= minOperationalAmount && fuzzAmount <= aliceInitialUSDCBalance);

    //     vm.startPrank(Alice);
    //     psm.approve(address(portal_USDC), 1e55);
    //     portal_USDC.buyPortalEnergy(Alice, fuzzAmount, 1, block.timestamp);
    //     vm.stopPrank();

    //     (, , , , portalEnergy, , ) = portal_USDC.getUpdateAccount(
    //         Alice,
    //         0,
    //         true
    //     );

    //     uint256 reserve1 = _TARGET_CONSTANT_USDC / _FUNDING_MIN_AMOUNT;
    //     uint256 netPSMinput = (fuzzAmount * 99) / 100;
    //     uint256 result = (netPSMinput * reserve1) /
    //         (netPSMinput + _FUNDING_MIN_AMOUNT);

    //     assert(portalEnergy == result);
    // }
    // bool setUpInvoked;

    // function check_testSuccess_buyPortalEnergy() public { 

    //     console2.log("codesize");
    //     helper_prepareSystem();

    //     // uint256 vie = svm.createUint(0,'vie');

    //     // setUpInvoked = true;
    //     // assertTrue(setUpInvoked);

    //     // uint256 portalEnergy;
    //     // (, , , , portalEnergy, , ) = portal_USDC.getUpdateAccount(
    //     //     address(Alice),
    //     //     vie,
    //     //     setUpInvoked
    //     // );
    
    // }
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

contract EmptyContract { }
contract EmptyContract2 { }
contract EmptyContract3 { }
contract EmptyContract4 { }
contract EmptyContract5 { }
contract EmptyContract6 { }
contract EmptyContract7 { }
contract EmptyContract8 { }
contract EmptyContract9 { }
