// SPDX-License-Identifier: MIT
pragma solidity ^0.5.2;

import "../HasMinters.sol";
import "./ERC20.sol";

contract ERC20Mintable is HasMinters, ERC20 {
  function mint(address _to, uint256 _value) public onlyMinter returns (bool _success) {
    return _mint(_to, _value);
  }

  function _mint(address _to, uint256 _value) internal returns (bool success) {
    totalSupply = totalSupply.add(_value);
    balanceOf[_to] = balanceOf[_to].add(_value);
    emit Transfer(address(0), _to, _value);
    return true;
  }
}
