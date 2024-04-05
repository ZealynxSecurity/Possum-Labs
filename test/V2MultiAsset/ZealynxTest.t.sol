// // SPDX-License-Identifier: UNLICENSED
// pragma solidity 0.8.19;

// import {Test, console2} from "forge-std/Test.sol";
// import {PortalV2MultiAsset} from "src/V2MultiAsset/PortalV2MultiAsset.sol";
// import {MintBurnToken} from "src/V2MultiAsset/MintBurnToken.sol";
// import {VirtualLP} from "src/V2MultiAsset/VirtualLP.sol";
// import {ErrorsLib} from "./libraries/ErrorsLib.sol";
// import {EventsLib} from "./libraries/EventsLib.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {IWater} from "src/V2MultiAsset/interfaces/IWater.sol";
// import {ISingleStaking} from "src/V2MultiAsset/interfaces/ISingleStaking.sol";
// import {IDualStaking} from "src/V2MultiAsset/interfaces/IDualStaking.sol";
// import {IPortalV2MultiAsset} from "src/V2MultiAsset/interfaces/IPortalV2MultiAsset.sol";

// contract ZealynxTest is Test {
// // External token addresses
//     address constant WETH_ADDRESS = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
//     address public constant PSM_ADDRESS =
//         0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5;
//     address constant esVKA = 0x95b3F9797077DDCa971aB8524b439553a220EB2A;

//     // Vaultka staking contracts
//     address constant SINGLE_STAKING =
//         0x314223E2fA375F972E159002Eb72A96301E99e22;
//     address constant DUAL_STAKING = 0x31Fa38A6381e9d1f4770C73AB14a0ced1528A65E;

//     uint256 constant _POOL_ID_USDC = 5;
//     uint256 constant _POOL_ID_WETH = 10;

//     address private constant USDC_WATER =
//         0x9045ae36f963b7184861BDce205ea8B08913B48c;
//     address private constant WETH_WATER =
//         0x8A98929750e6709Af765F976c6bddb5BfFE6C06c;

//     address private constant _PRINCIPAL_TOKEN_ADDRESS_USDC =
//         0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
//     address private constant _PRINCIPAL_TOKEN_ADDRESS_ETH = address(0);

//     // General constants
//     uint256 constant _TERMINAL_MAX_LOCK_DURATION = 157680000;
//     uint256 private constant SECONDS_PER_YEAR = 31536000; // seconds in a 365 day year
//     uint256 public maxLockDuration = 7776000; // 7776000 starting value for maximum allowed lock duration of user´s balance in seconds (90 days)
//     uint256 private constant OWNER_DURATION = 31536000; // 1 Year

//     // Portal Constructor values
//     uint256 constant _TARGET_CONSTANT_USDC = 440528634361 * 1e36;
//     uint256 constant _TARGET_CONSTANT_WETH = 125714213 * 1e36;

//     uint256 constant _FUNDING_PHASE_DURATION = 604800; // 7 days
//     uint256 constant _FUNDING_MIN_AMOUNT = 1e25; // 10M PSM

//     uint256 constant _DECIMALS = 18;
//     uint256 constant _DECIMALS_USDC = 6;

//     uint256 constant _AMOUNT_TO_CONVERT = 100000 * 1e18;

//     string _META_DATA_URI = "abcd";

//     // time
//     uint256 timestamp;
//     uint256 fundingPhase;
//     uint256 ownerExpiry;
//     uint256 hundredYearsLater;

//     // prank addresses
//     address payable Alice = payable(0x46340b20830761efd32832A74d7169B29FEB9758);
//     address payable Bob = payable(0xDD56CFdDB0002f4d7f8CC0563FD489971899cb79);
//     address payable Karen = payable(0x3A30aaf1189E830b02416fb8C513373C659ed748);

//     // Token Instances
//     IERC20 psm = IERC20(PSM_ADDRESS);
//     IERC20 usdc = IERC20(_PRINCIPAL_TOKEN_ADDRESS_USDC);
//     IERC20 weth = IERC20(WETH_ADDRESS);

//     // Portals & LP
//     PortalV2MultiAsset public portal_USDC;
//     PortalV2MultiAsset public portal_ETH;
//     VirtualLP public virtualLP;

//     // Simulated USDC distributor
//     address usdcSender = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

//     // PSM Treasury
//     address psmSender = 0xAb845D09933f52af5642FC87Dd8FBbf553fd7B33;

//     // starting token amounts
//     uint256 usdcAmount = 1e12; // 1M USDC
//     uint256 psmAmount = 1e25; // 10M PSM
//     uint256 usdcSendAmount = 1e9; // 1k USDC

//     ////////////// SETUP ////////////////////////
//     function setUp() public {
//         // Create Virtual LP instance
//         virtualLP = new VirtualLP(
//             psmSender,
//             _AMOUNT_TO_CONVERT,
//             _FUNDING_PHASE_DURATION,
//             _FUNDING_MIN_AMOUNT
//         );
//         address _VIRTUAL_LP = address(virtualLP);

//         // Create Portal instances
//         portal_USDC = new PortalV2MultiAsset(
//             _VIRTUAL_LP,
//             _TARGET_CONSTANT_USDC,
//             _PRINCIPAL_TOKEN_ADDRESS_USDC,
//             _DECIMALS_USDC,
//             "USD Coin",
//             "USDC",
//             _META_DATA_URI
//         );
//         portal_ETH = new PortalV2MultiAsset(
//             _VIRTUAL_LP,
//             _TARGET_CONSTANT_WETH,
//             _PRINCIPAL_TOKEN_ADDRESS_ETH,
//             _DECIMALS,
//             "ETHER",
//             "ETH",
//             _META_DATA_URI
//         );

//         // creation time
//         timestamp = block.timestamp;
//         fundingPhase = timestamp + _FUNDING_PHASE_DURATION;
//         ownerExpiry = timestamp + OWNER_DURATION;
//         hundredYearsLater = timestamp + 100 * SECONDS_PER_YEAR;

//         // Deal tokens to addresses
//         vm.deal(Alice, 1 ether);
//         vm.prank(psmSender);
//         psm.transfer(Alice, psmAmount);
//         vm.prank(usdcSender);
//         usdc.transfer(Alice, usdcAmount);

//         vm.deal(Bob, 1 ether);
//         vm.prank(psmSender);
//         psm.transfer(Bob, psmAmount);
//         vm.prank(usdcSender);
//         usdc.transfer(Bob, usdcAmount);

//         vm.deal(Karen, 1 ether);
//         vm.prank(psmSender);
//         psm.transfer(Karen, psmAmount);
//         vm.prank(usdcSender);
//         usdc.transfer(Karen, usdcAmount);
//     }

// //////////////////////////////////////////////////////

//             ////////////////////////////////////
//             ////////////////////////////////////
//                     //     FUZZ     //
//             ////////////////////////////////////
//             ////////////////////////////////////


// //////////////////
// // STAKE
// //////////////////

// //////////// testFuzzingStakeUSDC ////////////


//     function testFuzzingStakeUSDC(uint256 fuzzAmount) public {
//         // Preparar el sistema
//         helper_create_bToken();
//         helper_fundLP();
//         helper_registerPortalETH();
//         helper_registerPortalUSDC();
//         helper_activateLP();

//         // Configurar las aprobaciones en LP para USDC
//         virtualLP.increaseAllowanceDualStaking();
//         virtualLP.increaseAllowanceSingleStaking(address(portal_USDC));
//         virtualLP.increaseAllowanceVault(address(portal_USDC));

//         deal(address(usdc),Alice, 1e10);
//         uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);

//         // Asumir que fuzzAmount es menor que el balance de Alice y mayor que 0
//         // vm.assume(fuzzAmount <= aliceInitialUSDCBalance && fuzzAmount > 0);
//         vm.assume(fuzzAmount > 0 && fuzzAmount <= aliceInitialUSDCBalance);

//         // Aprobación y Stake
//         vm.startPrank(Alice);
//         usdc.approve(address(portal_USDC), fuzzAmount);
//         portal_USDC.stake(fuzzAmount);
//         vm.stopPrank();

//         uint256 aliceFinalUSDCBalance = usdc.balanceOf(Alice);

//         // Verificaciones
//         assertEq(aliceInitialUSDCBalance - fuzzAmount, aliceFinalUSDCBalance, "El balance de Alice despues del stake es incorrecto.");
//         assertEq(portal_USDC.totalPrincipalStaked(), fuzzAmount, "El total principal staked no coincide con el monto de stake.");
//     }

// //////////// invariant_StakeConsistencyUSDC ////////////


//     // function invariant_StakeConsistencyUSDC() public {
//     //     // Preparar el sistema
//     //     helper_prepareSystem();
//     //     helper_setApprovalsInLP_USDC();
//     //     // Asignar un balance de USDC a Alice para asegurar fondos suficientes para el staking.
//     //     uint256 initialFunds = 1e10;
//     //     deal(address(usdc), Alice, initialFunds);

//     //     // Guardar el estado inicial para comparar después del staking.
//     //     uint256 totalStakedBefore = portal_USDC.totalPrincipalStaked();
//     //     uint256 aliceBalanceBefore = usdc.balanceOf(Alice);

//     //     // Realizar una operación de staking.
//     //     uint256 stakeAmount = 1e6; // Un monto fijo para este ejemplo, en fuzzing sería variable.
//     //     vm.startPrank(Alice);
//     //     usdc.approve(address(portal_USDC), initialFunds);
//     //     portal_USDC.stake(stakeAmount);
//     //     vm.stopPrank();

//     //     // Verificar invariantes.
//     //     uint256 totalStakedAfter = portal_USDC.totalPrincipalStaked();
//     //     uint256 aliceBalanceAfter = usdc.balanceOf(Alice);

//     //     // Invariante 1: El total staked en el contrato debe incrementarse exactamente por `stakeAmount`.
//     //     assertEq(totalStakedBefore + stakeAmount, totalStakedAfter, "Total staked amount inconsistent");

//     //     // Invariante 2: El balance de USDC de Alice debe disminuir por `stakeAmount`.
//     //     assertEq(aliceBalanceBefore - stakeAmount, aliceBalanceAfter, "Alice's USDC balance inconsistent after staking");
//     // }

// //////////// testFuzzingStakeETH ////////////


//     function testFuzzingStakeETH(uint256 fuzzAmount) public {
//         // Preparar el sistema
//         helper_create_bToken();
//         helper_fundLP();
//         helper_registerPortalETH();
//         helper_registerPortalUSDC();
//         helper_activateLP();

//         virtualLP.increaseAllowanceDualStaking();
//         virtualLP.increaseAllowanceSingleStaking(address(portal_ETH));
//         virtualLP.increaseAllowanceVault(address(portal_ETH));

//         deal(address(weth),Alice, 1e10);
//         uint256 balanceBefore = Alice.balance;
//         // Asumir que fuzzAmount es menor que el balance de Alice y mayor que 0
//         vm.assume(fuzzAmount > 0 && fuzzAmount <= balanceBefore);

//         // Aprobación y Stake
//         vm.startPrank(Alice);
//         portal_ETH.stake{value: fuzzAmount}(fuzzAmount);

//         vm.stopPrank();

//         uint256 aliceFinalETHBalance =  Alice.balance;

//         // Verificaciones
//         assertEq(balanceBefore - fuzzAmount, aliceFinalETHBalance, "El balance de Alice despues del stake es incorrecto.");
//         assertEq(portal_ETH.totalPrincipalStaked(), fuzzAmount, "El total principal staked no coincide con el monto de stake.");
//     }

// //////////// invariant_StakeConsistencyETH ////////////


//     // function invariant_StakeConsistencyETH() public {
//     //     // Preparar el sistema
//     //     helper_prepareSystem();
//     //     helper_setApprovalsInLP_ETH();

//     //     uint256 initialFunds = 1e10;
//     //     deal(address(usdc), Alice, initialFunds);

//     //     uint256 totalStakedBefore = portal_ETH.totalPrincipalStaked();
//     //     uint256 aliceBalanceBefore = Alice.balance;

//     //     uint256 stakeAmount = 1e6; // Un monto fijo para este ejemplo, en fuzzing sería variable.
//     //     vm.startPrank(Alice);
//     //     portal_ETH.stake{value: stakeAmount}(stakeAmount);
//     //     vm.stopPrank();

//     //     uint256 totalStakedAfter = portal_ETH.totalPrincipalStaked();
//     //     uint256 aliceBalanceAfter = Alice.balance;

//     //     // Invariante 1: El total staked en el contrato debe incrementarse exactamente por `stakeAmount`.
//     //     assertEq(totalStakedBefore + stakeAmount, totalStakedAfter, "Total staked amount inconsistent");

//     //     // Invariante 2: El balance de USDC de Alice debe disminuir por `stakeAmount`.
//     //     assertEq(aliceBalanceBefore - stakeAmount, aliceBalanceAfter, "Alice's USDC balance inconsistent after staking");
//     // }


// //////////// testFuzz_Revert_stake_PortalNotRegistered ////////////


//     function testFuzz_Revert_stake_PortalNotRegistered(uint256 fuzzAmount) public {
//         helper_create_bToken();
//         helper_fundLP();
//         helper_activateLP();

//         deal(address(usdc),Alice, 1e10);
//         uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);

//         vm.assume(fuzzAmount > 0 && fuzzAmount <= aliceInitialUSDCBalance);

//         // Empezar a actuar como Alice
//         vm.startPrank(Alice);
        
//         // Aprobar el monto fuzzed para el contrato portal_USDC
//         usdc.approve(address(portal_USDC), fuzzAmount);

//         // Esperar que la transacción sea revertida debido a que el Portal no está registrado
//         vm.expectRevert(ErrorsLib.PortalNotRegistered.selector);

//         // Intentar hacer stake con el monto fuzzed
//         portal_USDC.stake(fuzzAmount);

//         // Detener la suplantación de Alice
//         vm.stopPrank();
//     }

// //////////// invariant_StakeAlwaysFailsWhenPortalNotRegistered ////////////

//     // function invariant_StakeAlwaysFailsWhenPortalNotRegistered() public {
//     //     uint256 initialFunds = 1e10;

//     //     // Preparar el sistema
//     //     helper_create_bToken();
//     //     helper_fundLP();
//     //     helper_activateLP();
//     //     deal(address(usdc), Alice, initialFunds);
//     //     vm.prank(Alice);
//     //     usdc.approve(address(portal_USDC), initialFunds);

//     //     uint256 fuzzAmount = uint256(keccak256(abi.encodePacked(block.timestamp, Alice))) % initialFunds + 1;
//     //     vm.assume(fuzzAmount > 0 && fuzzAmount <= initialFunds);

//     //     // Asegurar que Alice tiene suficiente USDC para el staking
//     //     if(usdc.balanceOf(Alice) < fuzzAmount) {
//     //         deal(address(usdc), Alice, fuzzAmount);
//     //     }

//     //     // Aprobar el monto fuzzed nuevamente por precaución
//     //     vm.startPrank(Alice);

//     //     usdc.approve(address(portal_USDC), fuzzAmount);

//     //     // Intentamos hacer stake, esperando que la operación falle consistentemente con PortalNotRegistered.
//     //     try portal_USDC.stake(fuzzAmount) {
//     //         // Si el stake no falla, entonces viola nuestra invariante
//     //         fail();
//     //     } catch (bytes memory reason) {
//     //         // Verifica que el revert es por el motivo esperado
//     //         assertTrue(keccak256(reason) == keccak256(abi.encodeWithSelector(ErrorsLib.PortalNotRegistered.selector)), "Failed for an unexpected reason");
//     //     }
//     //     vm.stopPrank();

//     // }


// //////////// testFuzz_Revert_stake_Zero ////////////

//     function testFuzz_Revert_stake_Zero(uint256 fuzzAmount) public {
//         // Registro del portal y activación del LP aquí
//         helper_create_bToken();
//         helper_fundLP();
//         helper_activateLP();
//         helper_registerPortalUSDC();

//         deal(address(usdc), Alice, 1e10); // Asegurar que Alice tiene suficiente USDC
//         uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);

//         // Asumir que fuzzAmount es válido y no cero
//         vm.assume(fuzzAmount > 0 && fuzzAmount <= aliceInitialUSDCBalance);

//         vm.startPrank(Alice);
        
//         // Aprobar el monto fuzzed para el contrato portal_USDC
//         usdc.approve(address(portal_USDC), fuzzAmount);

//         // Intentar hacer stake de 0 debería revertir con el error InvalidAmount
//         vm.expectRevert(ErrorsLib.InvalidAmount.selector);
//         portal_USDC.stake(0);

//         vm.stopPrank();
//     }
// //////////// testFuzz_Revert_stake_Ether ////////////


//     function testFuzz_Revert_stake_Ether(uint256 fuzzAmount) public {
//         // Registro del portal y activación del LP aquí
//         helper_create_bToken();
//         helper_fundLP();
//         helper_activateLP();
//         helper_registerPortalUSDC();

//         deal(address(usdc), Alice, 1e10); // Asegurar que Alice tiene suficiente USDC
//         uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);

//         // Asumir que fuzzAmount es válido y no cero
//         vm.assume(fuzzAmount > 0 && fuzzAmount <= aliceInitialUSDCBalance);

//         vm.startPrank(Alice);
        
//         // Aprobar el monto fuzzed para el contrato portal_USDC
//         usdc.approve(address(portal_USDC), fuzzAmount);


//         vm.expectRevert(ErrorsLib.NativeTokenNotAllowed.selector);
//         portal_USDC.stake{value: fuzzAmount}(fuzzAmount); // Envío de una cantidad fija de ether

//         vm.stopPrank();
//     }

// //////////// testFuzz_Revert_stake_0_InvalidAmount ////////////


//     function testFuzz_Revert_stake_0_InvalidAmount(uint256 fuzzAmount) public {
//         // Registro del portal y activación del LP aquí
//         helper_create_bToken();
//         helper_fundLP();
//         helper_registerPortalETH();
//         // helper_registerPortalUSDC();
//         helper_activateLP();
//         helper_setApprovalsInLP_ETH();

//         deal(address(weth), Alice, 1e10); // Asegurar que Alice tiene suficiente USDC
//         uint256 aliceInitialETHBalance = Alice.balance;

//         // Asumir que fuzzAmount es válido y no cero
//         vm.assume(fuzzAmount > 0 && fuzzAmount <= aliceInitialETHBalance);

//         vm.startPrank(Alice);

//         vm.expectRevert(ErrorsLib.InvalidAmount.selector);
//         portal_ETH.stake{value: 0}(fuzzAmount); // Envío de una cantidad fija de ether

//         vm.stopPrank();
//     }

// //////////// testFuzz_Revert_stake_InvalidAmount ////////////

// //@audit-issue 
//     function testFuzz_Revert_stake_InvalidAmount(uint256 fuzzAmount, uint256 _amount) public {
//         helper_create_bToken();
//         helper_fundLP();
//         helper_registerPortalETH();
//         // helper_registerPortalUSDC();
//         helper_activateLP();
//         helper_setApprovalsInLP_ETH();

//         deal(address(weth), Alice, 1e10); 
//         uint256 aliceInitialETHBalance = Alice.balance;

//         vm.assume(fuzzAmount > 0 && fuzzAmount <= aliceInitialETHBalance);
//         vm.assume(_amount > 0 && _amount <= aliceInitialETHBalance);
//         vm.assume (_amount != fuzzAmount);

//         vm.startPrank(Alice);

//         vm.expectRevert(ErrorsLib.InvalidAmount.selector);
//         portal_ETH.stake{value: _amount}(fuzzAmount); 

//         vm.stopPrank();
//     }

// //////////////////
// // UNSTAKE
// //////////////////


// //////////// testSuccess_unstake_USDC ////////////

//     function testSuccess_unstake_USDC(uint256 fuzzAmount) public {
//         // STAKE //
//         helper_prepareSystem();
//         helper_setApprovalsInLP_USDC();

//         uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
//         uint256 minOperationalAmount = 1e4; // Ejemplo de un mínimo operativo que considera las tarifas
//         vm.assume(fuzzAmount >= minOperationalAmount && fuzzAmount <= aliceInitialUSDCBalance);

//         vm.startPrank(Alice);
//         helper_Stake(Alice, fuzzAmount);
//         vm.stopPrank();

//         // UNSTAKE //
//         uint256 balanceBefore = usdc.balanceOf(Alice);
//         uint256 withdrawShares = IWater(USDC_WATER).convertToShares(fuzzAmount);
//         uint256 grossReceived = IWater(USDC_WATER).convertToAssets(
//             withdrawShares
//         );
//         uint256 denominator = IWater(USDC_WATER).DENOMINATOR();
//         uint256 fees = (grossReceived * IWater(USDC_WATER).withdrawalFees()) /
//             denominator;
//         uint256 netReceived = grossReceived - fees;

//         vm.warp(block.timestamp + 100);

//         vm.prank(Alice);
//         portal_USDC.unstake(fuzzAmount);

//         uint256 balanceAfter = usdc.balanceOf(Alice);

//         assertEq(balanceBefore, usdcAmount - fuzzAmount);
//         assertEq(balanceAfter, balanceBefore + netReceived);
//         assertTrue(balanceAfter <= usdcAmount);
//     }
//     function testRevert_unstake_InsufficientStakeBalance_USDC(uint256 fuzzAmount) public {
//         // STAKE //
//         helper_prepareSystem();
//         helper_setApprovalsInLP_USDC();

//         uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
//         uint256 minOperationalAmount = 1e4; // Ejemplo de un mínimo operativo que considera las tarifas
//         vm.assume(fuzzAmount >= minOperationalAmount && fuzzAmount <= aliceInitialUSDCBalance);

//         vm.startPrank(Alice);
//         helper_Stake(Alice, fuzzAmount);
//         vm.stopPrank();

//         // UNSTAKE //

//         vm.warp(block.timestamp + 100);

//         vm.prank(Alice);
//         vm.expectRevert(ErrorsLib.InvalidAmount.selector);
//         portal_USDC.unstake(0);
//         vm.stopPrank();

//         (, , uint256 stakedBalance, , )= portal_USDC.getAccountDetails(Alice);
//         // amount > user stake balance
//         vm.startPrank(psmSender);
//         psm.approve(address(portal_USDC), 1e55);
//         portal_USDC.buyPortalEnergy(Alice, 1e18, 1, hundredYearsLater);
//         vm.stopPrank();

//         vm.startPrank(Alice);
//         vm.expectRevert(ErrorsLib.InsufficientStakeBalance.selector);
//         portal_USDC.unstake(stakedBalance + 1);

//         vm.stopPrank();

//     }


// //////////// testSuccess_unstake_ETH ////////////

//     function testSuccess_unstake_ETH(uint256 fuzzAmount) public {
//         // STAKE //
//         helper_prepareSystem();
//         helper_setApprovalsInLP_ETH();

//         // deal(address(weth),Alice, 1e10);
//         uint256 balanceBefore2 = Alice.balance;
//         // Asumir que fuzzAmount es menor que el balance de Alice y mayor que 0
//          uint256 minOperationalAmount = 1e4; // Ejemplo de un mínimo operativo que considera las tarifas
//         vm.assume(fuzzAmount >= minOperationalAmount && fuzzAmount <= balanceBefore2);
//         // Aprobación y Stake
//         vm.startPrank(Alice);
//         portal_ETH.stake{value: fuzzAmount}(fuzzAmount);

//         vm.stopPrank();

//         uint256 aliceFinalETHBalance =  Alice.balance;

//         // Verificaciones
//         assertEq(balanceBefore2 - fuzzAmount, aliceFinalETHBalance, "El balance de Alice despues del stake es incorrecto.");
//         assertEq(portal_ETH.totalPrincipalStaked(), fuzzAmount, "El total principal staked no coincide con el monto de stake.");

//         // UNSTAKE //
//         uint256 balanceBefore = Alice.balance;
//         uint256 withdrawShares = IWater(WETH_WATER).convertToShares(fuzzAmount);
//         uint256 grossReceived = IWater(WETH_WATER).convertToAssets(
//             withdrawShares
//         );
//         uint256 denominator = IWater(WETH_WATER).DENOMINATOR();
//         uint256 fees = (grossReceived * IWater(WETH_WATER).withdrawalFees()) /
//             denominator;
//         uint256 netReceived = grossReceived - fees;

//         vm.warp(block.timestamp + 100);

//         vm.prank(Alice);
//         portal_ETH.unstake(fuzzAmount);

//         uint256 balanceAfter = Alice.balance;

//         assertEq(balanceBefore, 1e18 - fuzzAmount);
//         assertEq(balanceAfter, balanceBefore + netReceived);
//         assertTrue(balanceAfter <= 1e18);
//     }


// //////////////////
// // getUpdateAccount
// //////////////////

// //////////// testSuccess_getUpdateAccount ////////////

//     function testSuccess_getUpdateAccount(uint256 fuzzAmount) public {
//       // STAKE //
//         helper_prepareSystem();
//         helper_setApprovalsInLP_USDC();

//         uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
//         uint256 minOperationalAmount = 1e4; // Ejemplo de un mínimo operativo que considera las tarifas
//         vm.assume(fuzzAmount >= minOperationalAmount && fuzzAmount <= aliceInitialUSDCBalance);

//         vm.startPrank(Alice);
//         helper_Stake(Alice, fuzzAmount);
//         vm.stopPrank();


//         vm.startPrank(Alice);
//         (
//             uint256 lastUpdateTime,
//             uint256 lastMaxLockDuration,
//             uint256 stakedBalance,
//             uint256 maxStakeDebt,
//             uint256 portalEnergy,
//             uint256 availableToWithdraw,
//             uint256 portalEnergyTokensRequired
//         ) = portal_USDC.getUpdateAccount(Alice, 100, true);

//         assertEq(lastUpdateTime, block.timestamp);
//         assertEq(lastMaxLockDuration, portal_USDC.maxLockDuration());
//         assertEq(stakedBalance, fuzzAmount + 100);
//         assertEq(
//             maxStakeDebt,
//             (stakedBalance * lastMaxLockDuration * 1e18) /
//                 (SECONDS_PER_YEAR * portal_USDC.DECIMALS_ADJUSTMENT())
//         );
//         assertEq(portalEnergy, maxStakeDebt );
//         assertEq(availableToWithdraw, fuzzAmount + 100);
//         assertEq(portalEnergyTokensRequired, 0);

//         vm.stopPrank();
//     }


// //////////////////
// // create_portalNFT
// //////////////////

// //////////// testSuccess_mintNFTposition ////////////

//     function testSuccess_mintNFTposition(uint256 fuzzAmount, uint256 fuzzAmount2) public {
//         helper_createNFT();
//         // STAKE //
//         helper_prepareSystem();
//         helper_setApprovalsInLP_USDC();

//         uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
//         uint256 minOperationalAmount = 1e4; // Ejemplo de un mínimo operativo que considera las tarifas
//         vm.assume(fuzzAmount >= minOperationalAmount && fuzzAmount <= aliceInitialUSDCBalance);
//         vm.assume(fuzzAmount2 >= minOperationalAmount && fuzzAmount2 <= aliceInitialUSDCBalance && fuzzAmount2 != fuzzAmount);

//         vm.startPrank(Alice);
//         helper_Stake(Alice, fuzzAmount);
//         vm.stopPrank();

//         (
//             ,
//             uint256 lastMaxLockDurationBefore,
//             uint256 stakeBalanceBefore,
//             ,
//             uint256 peBalanceBefore,
//             ,

//         ) = portal_USDC.getUpdateAccount(Alice, 0, true);

//         vm.prank(Alice);
//         portal_USDC.mintNFTposition(Karen);

//         (
//             ,
//             uint256 lastMaxLockDurationAfter,
//             uint256 stakeBalanceAfter,
//             ,
//             ,
//             uint256 peBalanceAfter,

//         ) = portal_USDC.getUpdateAccount(Alice, fuzzAmount2, true);

//         assertTrue(lastMaxLockDurationBefore > 0);
//         assertTrue(stakeBalanceBefore > 0);
//         assertTrue(peBalanceBefore > 0);
//         assertEq(lastMaxLockDurationAfter, lastMaxLockDurationBefore);
//         assertEq(stakeBalanceAfter, fuzzAmount2);
//         assertEq(peBalanceAfter, fuzzAmount2);

//         (
//             uint256 nftMintTime,
//             uint256 nftLastMaxLockDuration,
//             uint256 nftStakedBalance,
//             uint256 nftPortalEnergy
//         ) = portal_USDC.portalNFT().accounts(1);

//         assertTrue(address(portal_USDC.portalNFT()) != address(0));
//         assertEq(nftMintTime, block.timestamp);
//         assertEq(nftLastMaxLockDuration, portal_USDC.maxLockDuration());
//         assertEq(nftStakedBalance, stakeBalanceBefore);
//         assertEq(nftPortalEnergy, peBalanceBefore);
//     }
//     function testSuccess_2_mintNFTposition(uint256 fuzzAmount) public {
//         helper_createNFT();
//         // STAKE //
//         helper_prepareSystem();
//         helper_setApprovalsInLP_USDC();

//         uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
//         uint256 minOperationalAmount = 1e4; // Ejemplo de un mínimo operativo que considera las tarifas
//         vm.assume(fuzzAmount >= minOperationalAmount && fuzzAmount <= aliceInitialUSDCBalance);

//         vm.startPrank(Alice);
//         helper_Stake(Alice, fuzzAmount);
//         vm.stopPrank();

//         (
//             ,
//             uint256 lastMaxLockDurationBefore,
//             uint256 stakeBalanceBefore,
//             ,
//             uint256 peBalanceBefore,
//             ,

//         ) = portal_USDC.getUpdateAccount(Alice, 0, true);

//         vm.prank(Alice);
//         portal_USDC.mintNFTposition(Karen);

//         (
//             ,
//             uint256 lastMaxLockDurationAfter,
//             uint256 stakeBalanceAfter,
//             ,
//             ,
//             uint256 peBalanceAfter,

//         ) = portal_USDC.getUpdateAccount(Alice, 0, true);

//         assertTrue(lastMaxLockDurationBefore > 0);
//         assertTrue(stakeBalanceBefore > 0);
//         assertTrue(peBalanceBefore > 0);
//         assertEq(lastMaxLockDurationAfter, lastMaxLockDurationBefore);
//         assertEq(stakeBalanceAfter, 0);
//         assertEq(peBalanceAfter, 0);

//         (
//             uint256 nftMintTime,
//             uint256 nftLastMaxLockDuration,
//             uint256 nftStakedBalance,
//             uint256 nftPortalEnergy
//         ) = portal_USDC.portalNFT().accounts(1);

//         assertTrue(address(portal_USDC.portalNFT()) != address(0));
//         assertEq(nftMintTime, block.timestamp);
//         assertEq(nftLastMaxLockDuration, portal_USDC.maxLockDuration());
//         assertEq(nftStakedBalance, stakeBalanceBefore);
//         assertEq(nftPortalEnergy, peBalanceBefore);
//     }

// //////////// test_EmptyAccount_mintNFTposition ////////////

//     function test_EmptyAccount_mintNFTposition(uint256 fuzzAmount, uint256 fuzzAmount2) public {
//         helper_createNFT();
//         // STAKE //
//         helper_prepareSystem();
//         helper_setApprovalsInLP_USDC();

//         uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
//         uint256 minOperationalAmount = 1e4; // Ejemplo de un mínimo operativo que considera las tarifas
//         vm.assume(fuzzAmount >= minOperationalAmount && fuzzAmount <= aliceInitialUSDCBalance);
//         vm.assume(fuzzAmount2 >= minOperationalAmount && fuzzAmount2 <= aliceInitialUSDCBalance && fuzzAmount2 != fuzzAmount);

//         vm.startPrank(Alice);
//         helper_Stake(Alice, fuzzAmount);
//         vm.stopPrank();

//         (
//             ,
//             uint256 lastMaxLockDurationBefore,
//             uint256 stakeBalanceBefore,
//             ,
//             uint256 peBalanceBefore,
//             ,

//         ) = portal_USDC.getUpdateAccount(Alice, 0, true);

//         vm.prank(Karen);
//         vm.expectRevert(ErrorsLib.EmptyAccount.selector);
//         portal_USDC.mintNFTposition(Karen);

//     }

    
// //////////////////
// // redeemNFTposition
// //////////////////

// //////////// testSuccess_redeemNFTposition ////////////

//     function testSuccess_redeemNFTposition(uint256 fuzzAmount) public {
//         testSuccess_2_mintNFTposition(fuzzAmount);
//         (
//             ,
//             ,
//             ,
//             uint256 stakeBalanceBefore,
//             ,
//             uint256 peBalanceBefore,

//         ) = portal_USDC.getUpdateAccount(Karen, 0, true);

//         assertEq(stakeBalanceBefore, 0);
//         assertEq(peBalanceBefore, 0);

//         vm.startPrank(Karen);
//         portal_USDC.redeemNFTposition(1);

//         (
//             ,
//             ,
//             ,
//             uint256 stakeBalanceAfter,
//             ,
//             uint256 peBalanceAfter,

//         ) = portal_USDC.getUpdateAccount(Karen, 0, true);

//         assertTrue(stakeBalanceAfter > 0);
//         assertTrue(peBalanceAfter > 0);
//     }

// //////////// test_2xredeemNFTposition ////////////
//     function test_2xredeemNFTposition(uint256 fuzzAmount) public {
//         testSuccess_2_mintNFTposition( fuzzAmount);
//         (
//             ,
//             ,
//             ,
//             uint256 stakeBalanceBefore,
//             ,
//             uint256 peBalanceBefore,

//         ) = portal_USDC.getUpdateAccount(Karen, 0, true);

//         assertEq(stakeBalanceBefore, 0);
//         assertEq(peBalanceBefore, 0);

//         vm.startPrank(Karen);
//         portal_USDC.redeemNFTposition(1);

//         (
//             ,
//             ,
//             ,
//             uint256 stakeBalanceAfter,
//             ,
//             uint256 peBalanceAfter,

//         ) = portal_USDC.getUpdateAccount(Karen, 0, true);

//         assertTrue(stakeBalanceAfter > 0);
//         assertTrue(peBalanceAfter > 0);
//         vm.expectRevert();
//         portal_USDC.redeemNFTposition(1);

//     }


// //////////////////
// // buyPortalEnergy
// //////////////////

// //////////// testSuccess_buyPortalEnergy ////////////

//     function testSuccess_buyPortalEnergy(uint256 fuzzAmount) public { // @audit-ok => FV
//         helper_prepareSystem();

//         uint256 portalEnergy;
//         (, , , , portalEnergy, , ) = portal_USDC.getUpdateAccount(
//             Alice,
//             0,
//             true
//         );
//         uint256 minOperationalAmount = 1e4; // Ejemplo de un mínimo operativo que considera las tarifas
//         uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
//         vm.assume(fuzzAmount >= minOperationalAmount && fuzzAmount <= aliceInitialUSDCBalance);

//         vm.startPrank(Alice);
//         psm.approve(address(portal_USDC), 1e55);
//         portal_USDC.buyPortalEnergy(Alice, fuzzAmount, 1, block.timestamp);
//         vm.stopPrank();

//         (, , , , portalEnergy, , ) = portal_USDC.getUpdateAccount(
//             Alice,
//             0,
//             true
//         );

//         uint256 reserve1 = _TARGET_CONSTANT_USDC / _FUNDING_MIN_AMOUNT;
//         uint256 netPSMinput = (fuzzAmount * 99) / 100;
//         uint256 result = (netPSMinput * reserve1) /
//             (netPSMinput + _FUNDING_MIN_AMOUNT);

//         assertEq(portalEnergy, result);
//     }

// //////////// testSuccess_buyPortalEnergy ////////////
//     function testRevert_buyPortalEnergy(uint256 fuzzAmount, uint256 fuzzAmount2) public {
//         helper_prepareSystem();

//         uint256 minOperationalAmount = 1e4; // Ejemplo de un mínimo operativo que considera las tarifas
//         uint256 aliceInitialUSDCBalance = usdc.balanceOf(Alice);
//         vm.assume(fuzzAmount >= minOperationalAmount && fuzzAmount <= aliceInitialUSDCBalance);
//         vm.assume(fuzzAmount2 < fuzzAmount && fuzzAmount2 != 0);
        
//         // amount 0
//         vm.startPrank(Alice);
//         vm.expectRevert(ErrorsLib.InvalidAmount.selector);
//         portal_USDC.buyPortalEnergy(Alice, 0, 1, block.timestamp);

//         // minReceived 0
//         vm.expectRevert(ErrorsLib.InvalidAmount.selector);
//         portal_USDC.buyPortalEnergy(Alice, 1e18, 0, block.timestamp);

//         // recipient address(0)
//         vm.expectRevert(ErrorsLib.InvalidAddress.selector);
//         portal_USDC.buyPortalEnergy(address(0), 1e18, 1, block.timestamp);

//         // received amount < minReceived
//         vm.expectRevert(ErrorsLib.InsufficientReceived.selector);
//         portal_USDC.buyPortalEnergy(Alice, fuzzAmount2, fuzzAmount, block.timestamp);
//     }




// //////////////////////////////////////////////////////
//             //////////////////
//             //     UNIT     //
//             //////////////////
//     function test_Correct_Stake() public {

//         uint256 amount = 1e7;
//         // First Step (prepareSystem)
//         helper_create_bToken();
//         helper_fundLP();
//         helper_registerPortalETH();
//         helper_registerPortalUSDC();
//         helper_activateLP();

//         // Second step (setApprovalsInLP_USDC )
//         virtualLP.increaseAllowanceDualStaking();
//         virtualLP.increaseAllowanceSingleStaking(address(portal_USDC));
//         virtualLP.increaseAllowanceVault(address(portal_USDC));

//         uint256 balanceBefore = usdc.balanceOf(Alice);

//         vm.startPrank(Alice);
//         usdc.approve(address(portal_USDC), 1e55);
//         console2.log("PRINCIPAL_TOKEN_ADDRESS",(portal_USDC.PRINCIPAL_TOKEN_ADDRESS()));
//         portal_USDC.stake(amount);
//         vm.stopPrank();

//         uint256 balanceAfter = usdc.balanceOf(Alice);

//         assertEq(balanceBefore - amount, balanceAfter);
//         assertEq(portal_USDC.totalPrincipalStaked(), amount);
//     }
//     function testSuccess_uinti_unstake_USDC() public { // @audit-ok
//         uint256 amount = 1e7;
//         helper_prepareSystem();
//         helper_setApprovalsInLP_USDC();

//          uint256 balanceBefore2 = usdc.balanceOf(Alice);

//         vm.startPrank(Alice);
//         usdc.approve(address(portal_USDC), 1e55);
//         console2.log("PRINCIPAL_TOKEN_ADDRESS",(portal_USDC.PRINCIPAL_TOKEN_ADDRESS()));
//         portal_USDC.stake(amount);
//         vm.stopPrank();

//         uint256 balanceAfter2 = usdc.balanceOf(Alice);

//         assertEq(balanceBefore2 - amount, balanceAfter2);
//         assertEq(portal_USDC.totalPrincipalStaked(), amount);


//          uint256 balanceBefore = usdc.balanceOf(Alice);
//         uint256 withdrawShares = IWater(USDC_WATER).convertToShares(amount);
//         uint256 grossReceived = IWater(USDC_WATER).convertToAssets(
//             withdrawShares
//         );
//         uint256 denominator = IWater(USDC_WATER).DENOMINATOR();
//         uint256 fees = (grossReceived * IWater(USDC_WATER).withdrawalFees()) /
//             denominator;
//         uint256 netReceived = grossReceived - fees;

//         vm.warp(block.timestamp + 100);

//         vm.prank(Alice);
//         portal_USDC.unstake(amount);

//         uint256 balanceAfter = usdc.balanceOf(Alice);

//         assertEq(balanceBefore, usdcAmount - amount);
//         assertEq(balanceAfter, balanceBefore + netReceived);
//         assertTrue(balanceAfter <= usdcAmount);
//     }
//     function test_No_Success_uinti_unstake_USDC() public { // @audit-ok
//         uint256 amount = 1e7;
//         helper_prepareSystem();
//         helper_setApprovalsInLP_USDC();

//          uint256 balanceBefore2 = usdc.balanceOf(Alice);

//         vm.startPrank(Alice);
//         usdc.approve(address(portal_USDC), 1e55);
//         console2.log("PRINCIPAL_TOKEN_ADDRESS",(portal_USDC.PRINCIPAL_TOKEN_ADDRESS()));
//         portal_USDC.stake(amount);
//         vm.stopPrank();

//         uint256 balanceAfter2 = usdc.balanceOf(Alice);

//         assertEq(balanceBefore2 - amount, balanceAfter2);
//         assertEq(portal_USDC.totalPrincipalStaked(), amount);


//         vm.warp(block.timestamp + 100);

//         (, , uint256 stakedBalance, , )= portal_USDC.getAccountDetails(Alice);
//         // amount > user stake balance
//         vm.startPrank(psmSender);
//         psm.approve(address(portal_USDC), 1e55);
//         portal_USDC.buyPortalEnergy(Alice, 1e18, 1, hundredYearsLater);
//         vm.stopPrank();

//         vm.startPrank(Alice);
//         vm.expectRevert(ErrorsLib.InsufficientStakeBalance.selector);
//         portal_USDC.unstake(stakedBalance + 1);

//         vm.stopPrank();
//     }
//     function testSuccess2_getUpdateAccount() public {
//         uint256 amount = 1e7;
//         helper_prepareSystem();
//         helper_setApprovalsInLP_USDC();

//         uint256 balanceBefore = usdc.balanceOf(Alice);

//         vm.startPrank(Alice);
//         usdc.approve(address(portal_USDC), 1e55);
//         portal_USDC.stake(amount);
//         vm.stopPrank();

//         uint256 balanceAfter = usdc.balanceOf(Alice);

//         assertEq(balanceBefore - amount, balanceAfter);
//         assertEq(portal_USDC.totalPrincipalStaked(), amount);

//         vm.startPrank(Alice);
//         (
//             uint256 lastUpdateTime,
//             uint256 lastMaxLockDuration,
//             uint256 stakedBalance,
//             uint256 maxStakeDebt,
//             uint256 portalEnergy,
//             uint256 availableToWithdraw,
//             uint256 portalEnergyTokensRequired
//         ) = portal_USDC.getUpdateAccount(Alice, 1000, true);

//         assertEq(lastUpdateTime, block.timestamp);
//         assertEq(lastMaxLockDuration, portal_USDC.maxLockDuration());
//         assertEq(stakedBalance, amount + 1000);
//         assertEq(
//             maxStakeDebt,
//             (stakedBalance * lastMaxLockDuration * 1e18) /
//                 (SECONDS_PER_YEAR * portal_USDC.DECIMALS_ADJUSTMENT())
//         );
//         assertEq(portalEnergy, maxStakeDebt);
//         assertEq(availableToWithdraw, amount + 1000);
//         assertEq(portalEnergyTokensRequired, 0);

//         vm.stopPrank();
//     }



//   ////////////// HELPER FUNCTIONS /////////////

//   ////////////// HELPER FUNCTIONS /////////////



//     function helper_Stake(address account, uint256 fuzzAmount) public {

//      // STAKE //
//         uint256 InitialUSDCBalance = usdc.balanceOf(account);

//         // Aprobación y Stake
//         vm.startPrank(account);
//         usdc.approve(address(portal_USDC), fuzzAmount);
//         portal_USDC.stake(fuzzAmount);
//         vm.stopPrank();

//         uint256 FinalUSDCBalance = usdc.balanceOf(account);

//         // Verificaciones
//         assertEq(InitialUSDCBalance - fuzzAmount, FinalUSDCBalance, "El balance de Alice despues del stake es incorrecto.");
//         assertEq(portal_USDC.totalPrincipalStaked(), fuzzAmount, "El total principal staked no coincide con el monto de stake.");

//     }
//     // create the bToken token
//     function helper_create_bToken() public {
//         virtualLP.create_bToken();
//     }

//     // fund the Virtual LP
//     function helper_fundLP() public {
//         vm.startPrank(psmSender);

//         psm.approve(address(virtualLP), 1e55);
//         virtualLP.contributeFunding(_FUNDING_MIN_AMOUNT);

//         vm.stopPrank();
//     }

//     // Register USDC Portal
//     function helper_registerPortalUSDC() public {
//         vm.prank(psmSender);
//         virtualLP.registerPortal(
//             address(portal_USDC),
//             _PRINCIPAL_TOKEN_ADDRESS_USDC,
//             USDC_WATER,
//             _POOL_ID_USDC
//         );
//     }

//     // Register ETH Portal
//     function helper_registerPortalETH() public {
//         vm.prank(psmSender);
//         virtualLP.registerPortal(
//             address(portal_ETH),
//             _PRINCIPAL_TOKEN_ADDRESS_ETH,
//             WETH_WATER,
//             _POOL_ID_WETH
//         );
//     }

//     // activate the Virtual LP
//     function helper_activateLP() public {
//         vm.warp(fundingPhase);
//         virtualLP.activateLP();
//     }

//     // fund and activate the LP and register both Portals
//     function helper_prepareSystem() public {
//         helper_create_bToken();
//         helper_fundLP();
//         helper_registerPortalETH();
//         helper_registerPortalUSDC();
//         helper_activateLP();
//     }

//     // Deploy the NFT contract
//     function helper_createNFT() public {
//         portal_USDC.create_portalNFT();
//     }

//     // Deploy the ERC20 contract for mintable Portal Energy
//     function helper_createPortalEnergyToken() public {
//         portal_USDC.create_portalEnergyToken();
//     }

//     // Increase allowance of tokens used by the USDC Portal
//     function helper_setApprovalsInLP_USDC() public {
//         virtualLP.increaseAllowanceDualStaking();
//         virtualLP.increaseAllowanceSingleStaking(address(portal_USDC));
//         virtualLP.increaseAllowanceVault(address(portal_USDC));
//     }

//     // Increase allowance of tokens used by the ETH Portal
//     function helper_setApprovalsInLP_ETH() public {
//         virtualLP.increaseAllowanceDualStaking();
//         virtualLP.increaseAllowanceSingleStaking(address(portal_ETH));
//         virtualLP.increaseAllowanceVault(address(portal_ETH));
//     }

//     // send USDC to LP when balance is required
//     function helper_sendUSDCtoLP() public {
//         vm.prank(usdcSender);
//         usdc.transfer(address(virtualLP), usdcSendAmount); // Send 1k USDC to LP
//     }

//     // simulate a full convert() cycle
//     function helper_executeConvert() public {
//         helper_sendUSDCtoLP();
//         vm.startPrank(psmSender);
//         psm.approve(address(virtualLP), 1e55);
//         virtualLP.convert(
//             _PRINCIPAL_TOKEN_ADDRESS_USDC,
//             msg.sender,
//             1,
//             block.timestamp
//         );
//         vm.stopPrank();
//     }

// }