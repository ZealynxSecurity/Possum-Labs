
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface ILeverageVault {
    function getUpdatedDebtAndValue(
        uint256 withdrawableAmount,
        uint256 getDebt
    )
        external
        view
        returns (uint256 currentDTV, uint256 amountInDAI, uint256 currentDebt);

    function getUtilizationRate() external view returns (uint256);

    function burn(uint256 amount) external;
}
