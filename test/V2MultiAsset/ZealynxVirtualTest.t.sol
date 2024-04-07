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

import {HandlerVirtual} from "./HandlerVirtual.sol";


contract ZealynxTest is Test {
// External token addresses
    // address constant WETH_ADDRESS = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; @audit-ok
    // address public constant PSM_ADDRESS = 0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5; @audit-ok
    // address constant esVKA = 0x95b3F9797077DDCa971aB8524b439553a220EB2A; @audit-ok

    // Vaultka staking contracts
    // address constant SINGLE_STAKING = 0x314223E2fA375F972E159002Eb72A96301E99e22; @audit-ok
    // address constant DUAL_STAKING = 0x31Fa38A6381e9d1f4770C73AB14a0ced1528A65E; @audit-ok

    uint256 constant _POOL_ID_USDC = 5;
    uint256 constant _POOL_ID_WETH = 10;

    // address private constant USDC_WATER = 0x9045ae36f963b7184861BDce205ea8B08913B48c;@audit-ok
    // address private constant WETH_WATER =0x8A98929750e6709Af765F976c6bddb5BfFE6C06c; @audit-ok

    // address private constant _PRINCIPAL_TOKEN_ADDRESS_USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; @audit-ok
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
        vm.deal(address(this), etherAmount);
    }

    // ============================================
    // ==             HELPER ACTIONS             ==
    // ============================================
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

    function _prepareLP(
        address testPortal,
        address testAsset,
        address testVault,
        uint256 testPid
    ) internal {
        _create_bToken();
        _fundLP();
        _register(
            testPortal,
            testAsset,
            testVault,
            testPid
        );
        _activateLP();
    }

    // create the bToken token
    function _create_bToken() internal {
        virtualLP.create_bToken();
    }

    // fund the Virtual LP
    function _fundLP() internal {
        uint256 fundingAmount = 1e18;

        vm.prank(psmSender);
        psm.approve(address(handlerVirtual), 1e55);
        vm.prank(psmSender);
        handlerVirtual._contributeFunding(_FUNDING_MIN_AMOUNT, address(psm), address(hbToken)) ;
    }

    // activate the Virtual LP
    function _activateLP() internal {
        vm.warp(fundingPhase);
        handlerVirtual._handler_activateLP();
    }

    // send USDC to LP when balance is required
    function helper_sendUSDCtoLP() internal {
        vm.prank(usdcSender);
        usdc.transfer(address(virtualLP), usdcSendAmount); // Send 1k USDC to LP
    }

    // simulate a full convert() cycle
    function helper_executeConvert() internal {
        helper_sendUSDCtoLP();
        vm.prank(psmSender);
        psm.approve(address(virtualLP), 1e55);
        vm.prank(psmSender);
        virtualLP.convert(
            address(_PRINCIPAL_TOKEN_ADDRESS_USDC),
            msg.sender,
            1,
            block.timestamp
        );
    }

    function _prepareYieldSourceUSDC(
        address testPortal,
        address testAsset,
        address testVault,
        uint256 testPid,
        uint256 _amount
    ) internal {
        _prepareLP(
            testPortal,
            testAsset,
            testVault,
            testPid
        );

        vm.prank(usdcSender);
        usdc.transfer(address(portal_USDC), _amount);

        vm.prank(address(portal_USDC));
        usdc.transfer(address(virtualLP), _amount);

        vm.prank(address(portal_USDC));
        usdc.approve(address(virtualLP), 1e55);
        vm.prank(address(portal_USDC));
        // handlerVirtual.increaseAllowanceVault(address(portal_USDC));
    }

    function prepare_contribution() internal {
        _create_bToken();

        uint256 fundingAmount = 1e8;
        vm.prank(Alice);
        MockToken(psm).approve(address(virtualLP), 1e55);

        vm.startPrank(psmSender);
        handlerVirtual._contributeFunding(fundingAmount, address(psm), address(hbToken));
        vm.stopPrank();
    }

    function prepare_convert() internal {
        vm.prank(Alice);
        prepare_contribution();

        // Precondition
        _fundLP();
        _activateLP();

        // Action
        helper_sendUSDCtoLP();
        vm.prank(psmSender);
        MockToken(psm).approve(address(virtualLP), 1e55);
        vm.prank(psmSender);
    }

    // ============================================
    // ==             TEST CASES                 ==
    // ============================================

    // function test_deposit_to_yield_source_usdc() public {
    //     // Preconditions
    //     uint256 _amount = 1000;
    //     _prepareYieldSourceUSDC(
    //         address(portal_USDC),
    //         _PRINCIPAL_TOKEN_ADDRESS_USDC,
    //         USDC_WATER,
    //         _POOL_ID_USDC,
    //         _amount
    //     );

    //     // Action
    //     vm.prank(address(portal_USDC));
    //     handlerVirtual._handler_depositToYieldSource(address(usdc), _amount);

    //     // Check that stake was processed correctly in Vault and staking contract
    //     // uint256 depositShares = IWater(USDC_WATER).convertToShares(_amount);
    //     // uint256 stakedShares = ISingleStaking(SINGLE_STAKING).getUserAmount(
    //     //     _POOL_ID_USDC,
    //     //     address(virtualLP)
    //     // );

    //     // // Verification
    //     // assertTrue(usdc.balanceOf(address(portal_USDC)) == 0);
    //     // assertTrue(depositShares == stakedShares);
    // }

    function test_burn_b_tokens() public {
        // Precondition
        uint256 _amount = 1000;
        
        uint256 withdrawAmount = (_amount *
            FUNDING_MAX_RETURN_PERCENT) / 1000;

        vm.prank(Alice);
        prepare_contribution();

        // Precondition
        _fundLP();
        _activateLP();

        // Action
        helper_sendUSDCtoLP();
        vm.prank(Alice);
        MockToken(psm).approve(address(virtualLP), 1e55);
        
        vm.startPrank(Alice);
        handlerVirtual._handler_convert(
            address(_PRINCIPAL_TOKEN_ADDRESS_USDC),
            msg.sender,
            1,
            block.timestamp,
            address(psm),
            address(hbToken)
        );
        vm.stopPrank();

        // vm.prank(Alice);
        // // (hbToken) = MockToken(address(handlerVirtual.hbToken()));
        // uint256 beforeBalance = hbToken.balanceOf(Alice);

        // uint256 burnable = handlerVirtual._handler_getBurnableBtokenAmount();

        // // Action
        // vm.prank(Alice);
        // hbToken.approve(address(virtualLP), 1e55);
        // vm.prank(Alice);
        // handlerVirtual._handler_burnBtokens(_amount,address(hbToken), address(psm));

        // // Verification
        // assertTrue(hbToken.balanceOf(Alice) == beforeBalance - withdrawAmount);
    }






    // function test_val() public {
    //     portal_USDC.create_portalNFT();
    //     vm.prank(Alice);
    //     portal_USDC.mintNFTposition(Karen);
    // }

    // function test_contribute(address _dualS, uint256 _asset) public {
    //     vm.startPrank(psmSender);
    //     psm.approve(address(virtualLP), 1e55);
    //     handlerVirtual._contributeFunding(_FUNDING_MIN_AMOUNT, address(psm), address(hbToken));
    //     vm.stopPrank();

    //     helper_registerPortalETH();
    //     helper_registerPortalUSDC();

    //     vm.warp(fundingPhase);
    //     handlerVirtual._activateLP();    

    //     // HandlerVirtual._increaseAllowanceDualStaking(address(esVKA), _dualS ); //@audit => no found
    //     handlerVirtual.increaseAllowanceSingleStaking(address(portal_USDC), _asset);
    // }
}