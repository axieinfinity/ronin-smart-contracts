pragma solidity ^0.5.2;

contract ILandMath {
  uint256 constant defaultMask = 0xffffffffffffffff00000000000000000000000000000000ffffffffffffffff;
  uint256 constant rowMask = 0x0000000000000000ffffffffffffffff00000000000000000000000000000000;
  uint256 constant colMask = 0x00000000000000000000000000000000ffffffffffffffff0000000000000000;

  function getTokenId(int256 _row, int256 _col) pure public returns (uint256) {
    require (-1000000 <= _row && _row <= 1000000 && -1000000 <= _col && _col <= 1000000);

    return ((uint256(_row) << 128) | (uint128(_col) << 64)) | defaultMask;
  }

  function decodeTokenId(uint256 _tokenId) pure public returns (int256 _row, int256 _col) {
    require((_tokenId & defaultMask) == defaultMask);

    int64 _rawRow = int64((_tokenId & rowMask) >> 128);
    int64 _rawCol = int64((_tokenId & colMask) >> 64);

    _row = int256(_rawRow);
    _col = int256(_rawCol);
  }
}
