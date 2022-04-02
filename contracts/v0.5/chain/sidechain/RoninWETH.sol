// SPDX-License-Identifier: MIT
pragma solidity ^0.5.17;

import "../../references/ERC20/ERC20Detailed.sol";
import "../../references/ERC20/ERC20Mintable.sol";

contract RoninWETH is ERC20Detailed, ERC20Mintable {
  constructor() public ERC20Detailed("Ronin Wrapped Ether", "WETH", 18) {}
}
