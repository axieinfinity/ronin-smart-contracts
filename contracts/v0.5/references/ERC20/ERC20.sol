// SPDX-License-Identifier: MIT
pragma solidity ^0.5.2;

import "../SafeMath.sol";
import "./IERC20.sol";

contract ERC20 is IERC20 {
  using SafeMath for uint256;

  uint256 public totalSupply;
  mapping(address => uint256) public balanceOf;
  mapping(address => mapping(address => uint256)) public allowance;

  function approve(address _spender, uint256 _value) public returns (bool _success) {
    allowance[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  function transfer(address _to, uint256 _value) public returns (bool _success) {
    require(_to != address(0));
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(_value);
    balanceOf[_to] = balanceOf[_to].add(_value);
    emit Transfer(msg.sender, _to, _value);
    return true;
  }

  function transferFrom(
    address _from,
    address _to,
    uint256 _value
  ) public returns (bool _success) {
    require(_to != address(0));
    balanceOf[_from] = balanceOf[_from].sub(_value);
    balanceOf[_to] = balanceOf[_to].add(_value);
    allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);
    emit Transfer(_from, _to, _value);
    return true;
  }
}
