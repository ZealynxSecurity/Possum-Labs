// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;


import {VirtualLP} from "src/V2MultiAsset/VirtualLP.sol";
import {PortalV2MultiAsset} from "src/V2MultiAsset/PortalV2MultiAsset.sol";

import {MockToken} from "./mocks/MockToken.sol";
import {esVKAToken} from "src/onchain/esVKAToken.sol";

import {console2} from "forge-std/Test.sol";



// ============================================
// ==              CUSTOM ERRORS             ==
// ============================================
error DeadlineExpired();
error DurationLocked();
error DurationTooLow();
error EmptyAccount();
error InactiveLP();
error InsufficientBalance();
error InsufficientReceived();
error InsufficientStakeBalance();
error InvalidAddress();
error InvalidAmount();
error InvalidConstructor();
error NativeTokenNotAllowed();
error TokenExists();


contract HandlerPortalV2 is PortalV2MultiAsset {


    uint256 constant _TARGET_CONSTANT_USDC = 440528634361 * 1e36;
    uint256 constant _AMOUNT_TO_CONVERT = 100000 * 1e18;
    uint256 constant _FUNDING_PHASE_DURATION = 604800; // 7 days
    uint256 constant _DECIMALS_USDC = 6;
    string _META_DATA_URI = "abcd";

    PortalV2MultiAsset public portal_USDC;



    uint256 public _DENOMINATOR = 31536000000000;


    // No es necesario declarar aquí VirtualLP y FiatTokenV2_2 ya que se pasan al constructor base.

    constructor(

        uint256 _FUNDING_MIN_AMOUNT, 
        address _virtualLPAddress, 
        address _PRINCIPAL_TOKEN_ADDRESS_USDC
    ) PortalV2MultiAsset(
        _virtualLPAddress,
        _TARGET_CONSTANT_USDC,
        _PRINCIPAL_TOKEN_ADDRESS_USDC,
        _DECIMALS_USDC,
        "USD Coin",
        "USDC",
        _META_DATA_URI
    ) {

    }

    // Otras funciones y lógica del contrato...




    function change() public {
        console2.log("test");
    }


}








