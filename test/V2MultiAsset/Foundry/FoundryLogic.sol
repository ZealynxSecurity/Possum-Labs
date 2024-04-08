// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FoundrySetup} from "./FoundrySetup.sol";

contract FoundryLogic is FoundrySetup {

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
    // create the bToken token
    function helper_create_bToken() public {
        virtualLP.create_bToken();
    }

    // fund the Virtual LP
    function _fundLP() internal {
        vm.prank(psmSender);
        psm.approve(address(virtualLP), 1e55);
        vm.prank(psmSender);
        virtualLP.contributeFunding(_FUNDING_MIN_AMOUNT);
    }

    // activate the Virtual LP
    function _activateLP() internal {
        vm.warp(fundingPhase);
        virtualLP.activateLP();
    }
     // activate the Virtual LP
    function helper_activateLP() public {
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
    ) internal {
        assertTrue(virtualLP.registeredPortals(testPortal) == true);
        assertTrue(virtualLP.vaults(testPortal, testAsset) == testVault);
        assertTrue(virtualLP.poolID(testPortal, testAsset) == testPid); 
    }
}