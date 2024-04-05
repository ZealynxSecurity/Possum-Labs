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

import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import "./Interfaces/interfaces.sol";
import {console2} from "forge-std/console2.sol";



contract Virtual_Halmos is SymTest, Test {
// External token addresses
    // address constant WETH_ADDRESS = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    Weth_address WETH_ADDRESS;

    // address public constant PSM_ADDRESS = 0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5;
    Psm_address PSM_ADDRESS;

    // address constant esVKA = 0x95b3F9797077DDCa971aB8524b439553a220EB2A;
    esvka esVKA;
    // Vaultka staking contracts
    // address constant SINGLE_STAKING = 0x314223E2fA375F972E159002Eb72A96301E99e22;
    single_staking SINGLE_STAKING;

    // address constant DUAL_STAKING = 0x31Fa38A6381e9d1f4770C73AB14a0ced1528A65E;
    dual_staking DUAL_STAKING;

    uint256 constant _POOL_ID_USDC = 5;
    uint256 constant _POOL_ID_WETH = 10;

    // address private constant USDC_WATER = 0x9045ae36f963b7184861BDce205ea8B08913B48c;
    usdc_water USDC_WATER;

    // address private constant WETH_WATER = 0x8A98929750e6709Af765F976c6bddb5BfFE6C06c;
    weth_water WETH_WATER;
    // address private constant _PRINCIPAL_TOKEN_ADDRESS_USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    principal_token_address_usdc _PRINCIPAL_TOKEN_ADDRESS_USDC;

    // address private constant _PRINCIPAL_TOKEN_ADDRESS_ETH = address(0);
    address _PRINCIPAL_TOKEN_ADDRESS_ETH;

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
    // address payable Alice = payable(0x46340b20830761efd32832A74d7169B29FEB9758);
    // address payable Bob = payable(0xDD56CFdDB0002f4d7f8CC0563FD489971899cb79);
    // address payable Karen = payable(0x3A30aaf1189E830b02416fb8C513373C659ed748);

    address public Alice2;
    address public Bob2;
    address public Karen2;

    address payable Alice;
    address payable Bob;
    address payable Karen;

    // Token Instances
    // IERC20 psm = IERC20(PSM_ADDRESS);
    // IERC20 usdc = IERC20(_PRINCIPAL_TOKEN_ADDRESS_USDC);
    // IERC20 weth = IERC20(WETH_ADDRESS);
    IERC20 public psm;
    IERC20 public weth;
    IERC20 public usdc;

    // Portals & LP
    PortalV2MultiAsset public portal_USDC;
    PortalV2MultiAsset public portal_ETH;

    VirtualLP public virtualLPInstance;
    address public virtualLPAddress;

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



        // Create Virtual LP instance
        virtualLPInstance = new VirtualLP(
            psmSender,
            _AMOUNT_TO_CONVERT,
            _FUNDING_PHASE_DURATION,
            _FUNDING_MIN_AMOUNT
        );
        virtualLPAddress = address(virtualLPInstance);


        // creation time
        timestamp = block.timestamp;
        fundingPhase = timestamp + _FUNDING_PHASE_DURATION;
        ownerExpiry = timestamp + OWNER_DURATION;
        hundredYearsLater = timestamp + 100 * SECONDS_PER_YEAR;

        // Deal tokens to addresses
        // vm.deal(Alice, 1 ether);
        // vm.prank(psmSender);
        // psm.transfer(Alice, psmAmount);
        // vm.prank(usdcSender);
        // usdc.transfer(Alice, usdcAmount);

        // vm.deal(Bob, 1 ether);
        // vm.prank(psmSender);
        // psm.transfer(Bob, psmAmount);
        // vm.prank(usdcSender);
        // usdc.transfer(Bob, usdcAmount);

        // vm.deal(Karen, 1 ether);
        // vm.prank(psmSender);
        // psm.transfer(Karen, psmAmount);
        // vm.prank(usdcSender);
        // usdc.transfer(Karen, usdcAmount);
    }


    function check_primera () public {
        virtualLPInstance.create_bToken();

    }



}