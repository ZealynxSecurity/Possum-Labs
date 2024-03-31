// SPDX-License-Identifier: GPL-2.0-only
pragma solidity =0.8.19;

import "./EchidnaSetup.sol";

contract EchidnaVirtualLP is EchidnaSetup {

    constructor() payable {}

    // function register(
    //     address testPortal,
    //     address testAsset,
    //     address testVault,
    //     uint256 testPid
    // ) private {
    //     hevm.prank(psmSender);
    //     virtualLP.registerPortal(
    //         testPortal, 
    //         testAsset, 
    //         testVault, 
    //         testPid
    //     );
    // }

    // /**
    //     REGISTER PORTAL
    //  */
    // /////////////// UNIT TESTS ///////////////
    // function test_register_portal_usdc() public {
    //     address testPortal = address(portal_USDC);
    //     address testAsset = _PRINCIPAL_TOKEN_ADDRESS_USDC; 
    //     address testVault = address(USDC_WATER);
    //     uint256 testPid = _POOL_ID_USDC;

    //     register(
    //         testPortal, 
    //         testAsset, 
    //         testVault, 
    //         testPid
    //     );

    //     // Validate the outcome
    //     assert(virtualLP.registeredPortals(testPortal) == true);
    //     assert(virtualLP.vaults(testPortal, testAsset) == testVault);
    //     assert(virtualLP.poolID(testPortal, testAsset) == testPid);    
    // }

    // function test_register_portal_eth() public {
    //     address testPortal = address(portal_ETH);
    //     address testAsset = _PRINCIPAL_TOKEN_ADDRESS_ETH; 
    //     address testVault = address(WETH_WATER);
    //     uint256 testPid = _POOL_ID_WETH;

    //     register(
    //         testPortal, 
    //         testAsset, 
    //         testVault, 
    //         testPid
    //     );

    //     // Validate the outcome
    //     assert(virtualLP.registeredPortals(testPortal) == true);
    //     assert(virtualLP.vaults(testPortal, testAsset) == testVault);
    //     assert(virtualLP.poolID(testPortal, testAsset) == testPid);    
    // }

    // function test_revert_register_portal_not_owner() public {
    //     address testPortal = address(portal_ETH);
    //     address testAsset = _PRINCIPAL_TOKEN_ADDRESS_ETH; 
    //     address testVault = address(WETH_WATER);
    //     uint256 testPid = _POOL_ID_WETH;
        
    //     hevm.prank(USER1);
    //     try 
    //         virtualLP.registerPortal(
    //             testPortal, 
    //             testAsset, 
    //             testVault, 
    //             testPid
    //         )
    //     {
    //         assert(false);
    //     } catch {
    //         assert(true);
    //     }
    // }

    /**
        REMOVE OWNER
     */
    /////////////// UNIT TESTS ///////////////
    function test_address_changed_to_zero() public {
        hevm.warp(block.timestamp + OWNER_DURATION + 1);
        address ownerBefore = virtualLP.owner.address;
        Debugger.log("Owner address before:", ownerBefore);
        Debugger.log("Owner address before:", psmSender);
        
        virtualLP.removeOwner();
        Debugger.log("Owner address after:", virtualLP.owner.address);
        assert(virtualLP.owner.address == address(0));
    }

    function test_revert_remove_owner() public {
        hevm.warp(OWNER_DURATION - 10);
        address ownerBefore = virtualLP.owner.address;
        Debugger.log("Owner address before:", ownerBefore);
        try virtualLP.removeOwner() {
            assert(false);
        } catch {
            assert(true);
        }
    }
}
