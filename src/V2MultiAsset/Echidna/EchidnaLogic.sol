// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./EchidnaSetup.sol";

contract EchidnaLogic is EchidnaSetup {

    constructor() payable {}

    function _register(
        address testPortal,
        address testAsset,
        address testVault,
        uint256 testPid
    ) internal {
        // Precondition
        hevm.prank(psmSender);
        try virtualLP.registerPortal(
            testPortal, 
            testAsset, 
            testVault, 
            testPid
        ) {
            // continue
        } catch {
            // Verification
            assert(false);
        }
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

    // fund the Virtual LP
    function _fundLP() internal {
        hevm.prank(psmSender);
        psm.approve(address(virtualLP), 1e55);
        hevm.prank(psmSender);
        try virtualLP.contributeFunding(_FUNDING_MIN_AMOUNT) {
            // continue
        } catch {
            // Verification
            assert(false);
        }
    }

    // activate the Virtual LP
    function _activateLP() internal {
        hevm.warp(fundingPhase);
        virtualLP.activateLP();
    }

    // send USDC to LP when balance is required
    function helper_sendUSDCtoLP() internal {
        hevm.prank(usdcSender);
        usdc.transfer(address(virtualLP), usdcSendAmount); // Send 1k USDC to LP
    }

    function _prepareYieldSourceUSDC(uint256 _amount) internal {
        _prepareLP();

        hevm.prank(usdcSender);
        usdc.transfer(address(portal_USDC), _amount);

        hevm.prank(address(portal_USDC));
        usdc.transfer(address(virtualLP), _amount);

        hevm.prank(address(portal_USDC));
        usdc.approve(address(virtualLP), 1e55);
        hevm.prank(address(portal_USDC));
        virtualLP.increaseAllowanceVault(address(portal_USDC));
        virtualLP.increaseAllowanceSingleStaking(address(portal_USDC));
        virtualLP.increaseAllowanceDualStaking();
    }

    function prepare_contribution() internal {
        uint256 _fundingAmount = 1e18;
        _create_bToken();

        hevm.prank(USER1);
        psm.approve(address(virtualLP), 1e55);
        hevm.prank(USER1);
        try virtualLP.contributeFunding(_fundingAmount) {
            // continue
        } catch {
            // Verification
            assert(false);
        }
    }

    function prepare_convert() internal {
        hevm.prank(USER1);
        prepare_contribution();

        // Precondition
        _fundLP();
        _activateLP();

        // Action
        helper_sendUSDCtoLP();
        hevm.prank(psmSender);
        psm.approve(address(virtualLP), 1e55);
        hevm.prank(psmSender);
    }

    function _assertPortalRegistered(
        address testPortal,
        address testAsset,
        address testVault,
        uint256 testPid
    ) internal view {
        assert(virtualLP.registeredPortals(testPortal) == true);
        assert(virtualLP.vaults(testPortal, testAsset) == testVault);
        assert(virtualLP.poolID(testPortal, testAsset) == testPid); 
    }
}