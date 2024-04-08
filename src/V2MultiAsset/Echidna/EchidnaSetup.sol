// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./EchidnaConfig.sol";

import "../PortalV2MultiAsset.sol";
import "../MintBurnToken.sol";
import {VirtualLP} from "src/V2MultiAsset/VirtualLP.sol";
import "./EchidnaConfig.sol";

contract EchidnaSetup is EchidnaConfig {
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

    uint256 internal DENOMINATOR;

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

    constructor() payable {
        hevm.roll(195078119); // sets the correct block number
        hevm.warp(1711625676); // sets the expected timestamp for the block number

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

        DENOMINATOR = SECONDS_PER_YEAR * _DECIMALS_USDC;

        // Deal tokens to addresses
        hevm.prank(psmSender);
        psm.transfer(USER1, psmAmount);
        hevm.prank(usdcSender);
        usdc.transfer(USER1, usdcAmount);
        
        hevm.prank(psmSender);
        psm.transfer(USER2, psmAmount);
        hevm.prank(usdcSender);
        usdc.transfer(USER2, usdcAmount);

        hevm.prank(psmSender);
        psm.transfer(USER3, psmAmount);
        hevm.prank(usdcSender);
        usdc.transfer(USER3, usdcAmount);
    }
}
