// SPDX-License-Identifier: MIT
pragma solidity ^0.5.2;

interface IERC20Detailed {
  function name() external view returns (string memory _name);

  function symbol() external view returns (string memory _symbol);

  function decimals() external view returns (uint8 _decimals);
}
