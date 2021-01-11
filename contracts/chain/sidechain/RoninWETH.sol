pragma solidity ^0.5.17;

import "@axie/contract-library/contracts/token/erc20/ERC20Detailed.sol";
import "@axie/contract-library/contracts/token/erc20/ERC20Extended.sol";
import "../common/ERC20SpenderWhitelist.sol";


contract RoninWETH is
  ERC20Detailed,
  ERC20Extended,
  ERC20SpenderWhitelist
{
  constructor ()
    ERC20Detailed("Ronin Wrapped Ether", "WETH", 18)
    public
  {}
}
