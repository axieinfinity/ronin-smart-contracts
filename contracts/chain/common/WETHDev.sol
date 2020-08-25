pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/token/erc20/ERC20Detailed.sol";
import "@axie/contract-library/contracts/token/erc20/ERC20Extended.sol";
import "@axie/contract-library/contracts/token/erc20/ERC20Mintable.sol";
import "./IWETH.sol";


contract WETHDev is IWETH, ERC20Detailed, ERC20Extended, ERC20Mintable {

  event Deposit(
    address sender,
    uint256 value
  );

  event Withdrawal(
    address sender,
    uint256 value
  );

  constructor ()
    ERC20Detailed("Wrapped Ether", "WETH", 18)
    public
  {
  }

  function deposit() external payable {
    balanceOf[msg.sender] += msg.value;

    emit Deposit(msg.sender, msg.value);
  }

  function withdraw(uint256 wad) external {
    require(balanceOf[msg.sender] >= wad);
    balanceOf[msg.sender] -= wad;
    msg.sender.transfer(wad);

    emit Withdrawal(msg.sender, wad);
  }
}
