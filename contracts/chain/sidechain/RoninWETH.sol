pragma solidity ^0.5.17;

import "@axie/contract-library/contracts/token/erc20/ERC20Detailed.sol";
import "@axie/contract-library/contracts/token/erc20/ERC20Mintable.sol";


contract RoninWETH is ERC20Detailed, ERC20Mintable {
  constructor () ERC20Detailed("Ronin Wrapped Ether", "WETH", 18)
    public
  {}
}
