// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IVKA {
    function totalSupply() external view returns (uint256);
}

contract esVKAToken is IERC20, Ownable {
    address public VKA;

    string public name;
    string public symbol;

    uint8 public constant decimals = 18;
    uint256 public totalSupply = 55_000_000e18;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;
    mapping(address => bool) public isRecipientAllowed;
    mapping(address => bool) public isHandler;

    bool public inPrivateTransferMode;

    using SafeERC20 for IERC20;

    constructor() {
        name = "esVKA";
        symbol = "esVKA";
        // VKA = _VKA;
        // require(totalSupply < IVKA(VKA).totalSupply(), "Wrong total supply");
        _mint(msg.sender, totalSupply);
    }

    function setRecipientAllowed(address _handler, bool _status) external onlyOwner {
        isRecipientAllowed[_handler] = _status;
    }

    function setInPrivateTransferMode(bool _inPrivateTransferMode) external onlyOwner {
        inPrivateTransferMode = _inPrivateTransferMode;
    }

    function setHandler(address _handler, bool _isActive) external onlyOwner {
        isHandler[_handler] = _isActive;
    }

    function balanceOf(address _account) external view override returns (uint256) {
        return balances[_account];
    }

    function transfer(address _recipient, uint256 _amount) external override returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) external view override returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(address _spender, uint256 _amount) external override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) external override returns (bool) {
        uint256 currentAllowance = allowances[_sender][msg.sender];
        require(currentAllowance >= _amount, "esVKA: transfer amount exceeds allowance");

        uint256 nextAllowance = currentAllowance - _amount;
        _approve(_sender, msg.sender, nextAllowance);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    function burn(uint256 _amount) external {
        require(isHandler[msg.sender], "not a handler");
        _burn(msg.sender, _amount);
    }

    function _mint(address _account, uint256 _amount) internal {
        //@dev mint function will only be called once when the contract is deployed
        // require(_account != address(0), "esVKA: mint to the zero address");
        totalSupply += _amount;
        balances[_account] += _amount;

        emit Transfer(address(0), _account, _amount);
    }

    function _burn(address _account, uint256 _amount) internal {
        // require(_account != address(0), "esVKA: burn from the zero address");
        //@dev _burn function can only be called by handlers, which will not be 0 address

        balances[_account] -= _amount;
        totalSupply -= _amount;

        emit Transfer(_account, address(0), _amount);
    }

    //_transfer is only allowed to whitelisted recipient or senders
    //Whitelisted contracts will be vesters, pools, or other contracts that needs to reward es tokens
    //or accept the vesting of es tokens
    //not transferrable between users
    function _transfer(address _sender, address _recipient, uint256 _amount) private {
        // require(_sender != address(0), "esVKA: transfer from the zero address");
        require(_recipient != address(0), "esVKA: transfer to the zero address");
        require(
            isRecipientAllowed[_recipient] || isRecipientAllowed[_sender],
            "esVKA: recipient or sender not whitelisted"
        );

        balances[_sender] -= _amount;
        balances[_recipient] += _amount;

        emit Transfer(_sender, _recipient, _amount);
    }

    function _approve(address _owner, address _spender, uint256 _amount) private {
        // require(_owner != address(0), "esVKA: approve from the zero address");
        require(_spender != address(0), "esVKA: approve to the zero address");

        allowances[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);
    }


    function safeIncreaseAllowance(address token, address spender, uint256 value) public {
        safeIncreaseAllowance(token, spender, value);
    }

}
