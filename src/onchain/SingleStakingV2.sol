// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;


contract SingleStakingV2 is ISingleStaking, OwnableUpgradeable {
    /// @notice function to get the amount of staked token for a user
    /// @param _pid pool id
    /// @param _user user address
    /// @return amount of staked token
    function getUserAmount() public view returns (uint256) {
        return 5;
    }

}
