// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract MockERC721 is ERC721PresetMinterPauserAutoId {
  constructor(
    string memory name,
    string memory symbol,
    string memory baseTokenURI
  ) ERC721PresetMinterPauserAutoId(name, symbol, baseTokenURI) {}

  function mint(address _to, uint256 _id) public virtual returns (bool) {
    require(hasRole(MINTER_ROLE, _msgSender()), "MockERC721: must have minter role to mint");
    _mint(_to, _id);
    return true;
  }
}
