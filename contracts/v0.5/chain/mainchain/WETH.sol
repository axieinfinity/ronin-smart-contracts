// SPDX-License-Identifier: MIT
pragma solidity ^0.5.17;

import "../../references/ERC20/ERC20Detailed.sol";
import "../../references/ERC20/ERC20Mintable.sol";

contract WETH is ERC20Detailed {
  event Deposit(address _sender, uint256 _value);

  event Withdrawal(address _sender, uint256 _value);

  constructor() public ERC20Detailed("Wrapped Ether", "WETH", 18) {}

  function deposit() external payable {
    balanceOf[msg.sender] += msg.value;

    emit Deposit(msg.sender, msg.value);
  }

  function withdraw(uint256 _wad) external {
    require(balanceOf[msg.sender] >= _wad);
    balanceOf[msg.sender] -= _wad;
    msg.sender.transfer(_wad);

    emit Withdrawal(msg.sender, _wad);
  }
}
