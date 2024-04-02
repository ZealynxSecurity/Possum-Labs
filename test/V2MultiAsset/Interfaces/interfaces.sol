// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;
interface Weth_address {
  function admin (  ) external returns ( address admin_ );
  function changeAdmin ( address newAdmin ) external;
  function implementation (  ) external returns ( address implementation_ );
  function upgradeTo ( address newImplementation ) external;
  function upgradeToAndCall ( address newImplementation, bytes calldata data ) external;
}
interface Psm_address {
}
interface esvka {
  function VKA (  ) external view returns ( address );
  function allowance ( address _owner, address _spender ) external view returns ( uint256 );
  function allowances ( address, address ) external view returns ( uint256 );
  function approve ( address _spender, uint256 _amount ) external returns ( bool );
  function balanceOf ( address _account ) external view returns ( uint256 );
  function balances ( address ) external view returns ( uint256 );
  function burn ( uint256 _amount ) external;
  function decimals (  ) external view returns ( uint8 );
  function inPrivateTransferMode (  ) external view returns ( bool );
  function isHandler ( address ) external view returns ( bool );
  function isRecipientAllowed ( address ) external view returns ( bool );
  function name (  ) external view returns ( string memory);
  function owner (  ) external view returns ( address );
  function renounceOwnership (  ) external;
  function setHandler ( address _handler, bool _isActive ) external;
  function setInPrivateTransferMode ( bool _inPrivateTransferMode ) external;
  function setRecipientAllowed ( address _handler, bool _status ) external;
  function symbol (  ) external view returns ( string memory );
  function totalSupply (  ) external view returns ( uint256 );
  function transfer ( address _recipient, uint256 _amount ) external returns ( bool );
  function transferFrom ( address _sender, address _recipient, uint256 _amount ) external returns ( bool );
  function transferOwnership ( address newOwner ) external;
}
interface single_staking {
}

interface dual_staking {
  function accUSDCperTokens (  ) external view returns ( uint256 );
  function claimProtocolFee (  ) external;
  function compound (  ) external;
  function debtRecord ( address ) external view returns ( uint256 debtUSDC, uint256 depositTimestamp );
  function depositBalances ( address, address ) external view returns ( uint256 );
  function earned ( address account ) external view returns ( uint256 );
  function getReward (  ) external;
  function getRewardForDuration (  ) external view returns ( uint256 );
  function isHandler ( address ) external view returns ( bool );
  function isTreasury ( address ) external view returns ( bool );
  function lastStakedTime ( address ) external view returns ( uint256 );
  function lastTimeRewardApplicable (  ) external view returns ( uint256 );
  function lastUpdateTime (  ) external view returns ( uint256 );
  function notifyRewardAmount ( uint256 reward ) external;
  function owner (  ) external view returns ( address );
  function paused (  ) external view returns ( bool );
  function pendingRewardsESVKA ( address account ) external view returns ( uint256 yetToBePaidReward );
  function pendingRewardsUSDC ( address account ) external view returns ( uint256 );
  function periodFinish (  ) external view returns ( uint256 );
  function receiveProtocolFees ( uint256 _amount ) external;
  function renounceOwnership (  ) external;
  function rewardPerToken (  ) external view returns ( uint256 );
  function rewardPerTokenStored (  ) external view returns ( uint256 );
  function rewardRate (  ) external view returns ( uint256 );
  function rewardToken (  ) external view returns ( address );
  function rewardTokenForDistribution (  ) external view returns ( uint256 );
  function rewards ( address ) external view returns ( uint256 );
  function rewardsDuration (  ) external view returns ( uint256 );
  function rewardsUSDC (  ) external view returns ( uint256 );
  function setRewardsDuration ( uint256 _rewardsDuration ) external;
  function setTreasury ( address _treasury, bool _isActive ) external;
  function setWithdrawalTimeLock ( uint256 newTimeLock ) external;
  function stake ( uint256 amount, address token ) external;
  function stakedAmounts ( address ) external view returns ( uint256 );
  function stakingToken1 (  ) external view returns ( address );
  function stakingToken2 (  ) external view returns ( address );
  function totalStakedAmount (  ) external view returns ( uint256 );
  function transferOwnership ( address newOwner ) external;
  function usdcToken (  ) external view returns ( address );
  function userRewardPerTokenPaid ( address ) external view returns ( uint256 );
  function withdraw ( uint256 amount, address token ) external;
  function withdrawalTimeLock (  ) external view returns ( uint256 );
}

interface usdc_water {
  function admin (  ) external returns ( address admin_ );
  function changeAdmin ( address newAdmin ) external;
  function implementation (  ) external returns ( address implementation_ );
  function upgradeTo ( address newImplementation ) external;
  function upgradeToAndCall ( address newImplementation, bytes calldata data ) external;
}

interface weth_water {
}

interface principal_token_address_usdc {
  function admin (  ) external view returns ( address );
  function changeAdmin ( address newAdmin ) external;
  function implementation (  ) external view returns ( address );
  function upgradeTo ( address newImplementation ) external;
  function upgradeToAndCall ( address newImplementation, bytes calldata data ) external;
}


