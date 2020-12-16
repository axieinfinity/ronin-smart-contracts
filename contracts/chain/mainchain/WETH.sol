pragma solidity ^0.5.17;

import "@axie/contract-library/contracts/token/erc20/ERC20Detailed.sol";
import "@axie/contract-library/contracts/token/erc20/ERC20Mintable.sol";


contract WETH is ERC20Detailed {

  event Deposit(
    address _sender,
    uint256 _value
  );

  event Withdrawal(
    address _sender,
    uint256 _value
  );

  constructor () ERC20Detailed("Wrapped Ether", "WETH", 18)
    public
  {}

  function deposit()
    external
    payable
  {
    balanceOf[msg.sender] += msg.value;

    emit Deposit(msg.sender, msg.value);
  }

  function withdraw(uint256 _wad)
    external
  {
    require(balanceOf[msg.sender] >= _wad);
    balanceOf[msg.sender] -= _wad;
    msg.sender.transfer(_wad);

    emit Withdrawal(msg.sender, _wad);
  }
}
