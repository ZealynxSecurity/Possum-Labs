// SPDX-License-Identifier: GPL-2.0-only
pragma solidity =0.8.19;

import "./EchidnaSetup.sol";

contract EchidnaVirtualLP is EchidnaSetup {

    constructor() payable {}

    /**
        REGISTER PORTAL
     */
    /////////////// UNIT TESTS ///////////////
    function test_register_portal_usdc() public {
        address testPortal = address(portal_USDC);
        address testAsset = _PRINCIPAL_TOKEN_ADDRESS_USDC; 
        address testVault = address(USDC_WATER);
        uint256 testPid = _POOL_ID_USDC;

        hevm.prank(psmSender);
        virtualLP.registerPortal(
            testPortal, 
            testAsset, 
            testVault, 
            testPid
        );

        // Validate the outcome
        assert(virtualLP.registeredPortals(testPortal) == true);
        assert(virtualLP.vaults(testPortal, testAsset) == testVault);
        assert(virtualLP.poolID(testPortal, testAsset) == testPid);    
    }

    function test_register_portal_eth() public {
        address testPortal = address(portal_ETH);
        address testAsset = _PRINCIPAL_TOKEN_ADDRESS_ETH; 
        address testVault = address(WETH_WATER);
        uint256 testPid = _POOL_ID_WETH;

        hevm.prank(psmSender);
        virtualLP.registerPortal(
            testPortal, 
            testAsset, 
            testVault, 
            testPid
        );

        // Validate the outcome
        assert(virtualLP.registeredPortals(testPortal) == true);
        assert(virtualLP.vaults(testPortal, testAsset) == testVault);
        assert(virtualLP.poolID(testPortal, testAsset) == testPid);    
    }

    function test_register_portal_only_owner() public {
        address testPortal = address(portal_ETH);
        address testAsset = _PRINCIPAL_TOKEN_ADDRESS_ETH; 
        address testVault = address(WETH_WATER);
        uint256 testPid = _POOL_ID_WETH;
        
        hevm.prank(USER1);
        virtualLP.registerPortal(
            testPortal, 
            testAsset, 
            testVault, 
            testPid
        );

        // Validate the outcome
        assert(virtualLP.registeredPortals(testPortal) == true);
        assert(virtualLP.vaults(testPortal, testAsset) == testVault);
        assert(virtualLP.poolID(testPortal, testAsset) == testPid);    
    }
}
