pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/access/HasAdmin.sol";
import './ILandMath.sol';


contract EstateStorage is HasAdmin, ILandMath {
  mapping (uint256 => string) public estateData;

  function setEstateData(int256 _row, int256 _col, string calldata _data) onlyAdmin external {
    uint256 _tokenId = getTokenId(_row, _col);

    estateData[_tokenId] = _data;
  }

  function getEstateData(int256 _row, int256 _col) view external returns (string memory) {
    uint256 _tokenId = getTokenId(_row, _col);

    return estateData[_tokenId];
  }
}
