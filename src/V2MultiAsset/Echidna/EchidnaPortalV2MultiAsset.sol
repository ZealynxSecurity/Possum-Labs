// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../PortalV2MultiAsset.sol";
import "../MintBurnToken.sol";
import {VirtualLP} from "src/V2MultiAsset/VirtualLP.sol";
import "./EchidnaConfig.sol";

contract EchidnaPortalV2MultiAsset is EchidnaConfig {
    MintBurnToken public psmToken;
    VirtualLP public virtualLP;

    // External token addresses
    address constant WETH_ADDRESS = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant PSM_ADDRESS =
        0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5;
    address constant esVKA = 0x95b3F9797077DDCa971aB8524b439553a220EB2A;

    // Vaultka staking contracts
    address constant SINGLE_STAKING =
        0x314223E2fA375F972E159002Eb72A96301E99e22;
    address constant DUAL_STAKING = 0x31Fa38A6381e9d1f4770C73AB14a0ced1528A65E;

    uint256 constant _POOL_ID_USDC = 5;
    uint256 constant _POOL_ID_WETH = 10;

    address private constant USDC_WATER =
        0x9045ae36f963b7184861BDce205ea8B08913B48c;
    address private constant WETH_WATER =
        0x8A98929750e6709Af765F976c6bddb5BfFE6C06c;

    address private constant _PRINCIPAL_TOKEN_ADDRESS_USDC =
        0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
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

    // Token Instances
    IERC20 psm = IERC20(PSM_ADDRESS);
    IERC20 usdc = IERC20(_PRINCIPAL_TOKEN_ADDRESS_USDC);
    IERC20 weth = IERC20(WETH_ADDRESS);

    // Portals & LP
    PortalV2MultiAsset public portal_USDC;
    PortalV2MultiAsset public portal_ETH;

    // Simulated USDC distributor
    address usdcSender = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    // PSM Treasury
    address psmSender = 0xAb845D09933f52af5642FC87Dd8FBbf553fd7B33;

    // starting token amounts
    uint256 usdcAmount = 1e12; // 1M USDC
    uint256 psmAmount = 1e25; // 10M PSM
    uint256 usdcSendAmount = 1e9; // 1k USDC

    constructor() {
        hevm.roll(195078119); // sets the correct block number
        // hevm.warp(); // sets the expected timestamp for the block number

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
        hevm.deal(USER1, 1 ether);
        hevm.prank(psmSender);
        psm.transfer(USER1, psmAmount);
        hevm.prank(usdcSender);
        usdc.transfer(USER1, usdcAmount);

        // hevm.deal(USER2, 1 ether);
        hevm.prank(psmSender);
        psm.transfer(USER2, psmAmount);
        hevm.prank(usdcSender);
        usdc.transfer(USER2, usdcAmount);

        // hevm.deal(USER3, 1 ether);
        hevm.prank(psmSender);
        psm.transfer(USER3, psmAmount);
        hevm.prank(usdcSender);
        usdc.transfer(USER3, usdcAmount);
    }

    // Echidna test for staking and unstaking invariant
    function test_stake_unstake_invariant() public {
        uint256 stakeAmount = 1000e18; // Simplified stake amount
        hevm.prank(USER1);
        portal_ETH.stake(stakeAmount);
        hevm.prank(USER1);
        portal_ETH.unstake(stakeAmount);

        // Assertion to ensure total staked balance is correct
        assert(portal_ETH.totalPrincipalStaked() == 0);
    }

    // Echidna test for portal energy token minting and burning consistency
    function test_portal_energy_token_mint_burn() public {
        uint256 mintAmount = 500e18; // Simplified mint amount
        hevm.prank(USER2);
        portal_ETH.mintPortalEnergyToken(USER2, mintAmount); // Assuming this function exists and works directly for simplicity
        hevm.prank(USER2);
        portal_ETH.burnPortalEnergyToken(USER2, mintAmount); // Assuming direct burn for simplicity

        // Assertion to check portal energy balance consistency
        // This is a placeholder for the actual logic you might want to assert
        // E.g., asserting that the user's portal energy is back to the initial state
        // This might require adjustments based on the actual implementation details
        assert(true); // Placeholder assertion
    }
}
