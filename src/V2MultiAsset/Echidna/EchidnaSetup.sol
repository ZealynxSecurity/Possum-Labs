// // SPDX-License-Identifier: MIT

// import "./IHevm.sol";
// import "./EchidnaConfig.sol";
// import "./Debugger.sol";
// import "./Account.sol";

// import "../interfaces/IUSDC.sol";
// import "../interfaces/IcEther.sol";

// contract EchidnaSetup is EchidnaConfig {

//     Account account0 = new Account(0);
//     Account account1 = new Account(2);
//     Account account2 = new Account(128);

//     IUSDC usdc = IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
//     IcEther fEth = IcEther(payable(0x26267e41CeCa7C8E0f143554Af707336f27Fa051));

//     constructor() {
//         // not sure if still necessary, but just in case
//         hevm.roll(195078119);

//         hevm.prank(usdc.masterMinter());
//         usdc.configureMinter(address(this), type(uint256).max);

//         ADDRESS_ACCOUNT0 = payable(address(account0));
//         ADDRESS_ACCOUNT0 = payable(address(account1));
//         ADDRESS_ACCOUNT2 = payable(address(account2));

//         ADDRESS_ACCOUNT0.transfer(STARTING_ETH_BALANCE);
//         ADDRESS_ACCOUNT1.transfer(STARTING_ETH_BALANCE);
//         ADDRESS_ACCOUNT2.transfer(STARTING_ETH_BALANCE);

//         usdc.mint(ADDRESS_ACCOUNT0, STARTING_TOKEN_BALANCE);
//         usdc.mint(ADDRESS_ACCOUNT1, STARTING_TOKEN_BALANCE);
//         usdc.mint(ADDRESS_ACCOUNT2, STARTING_TOKEN_BALANCE);

//         hevm.prank(ADDRESS_ACCOUNT0);
//         usdc.approve(address(fUsdc), type(uint256).max);
//         hevm.prank(ADDRESS_ACCOUNT1);
//         usdc.approve(address(fUsdc), type(uint256).max);
//         hevm.prank(ADDRESS_ACCOUNT2);
//         usdc.approve(address(fUsdc), type(uint256).max);
//     }
// }
