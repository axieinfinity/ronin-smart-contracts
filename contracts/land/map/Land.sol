pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/access/HasMinters.sol";
import "@axie/contract-library/contracts/token/erc721/ERC721FullPausable.sol";
import './EstateStorage.sol';


contract Land is HasMinters, ERC721FullPausable, EstateStorage {
  constructor(
    string memory _baseTokenURI
  )
    public
    ERC721FullPausable('Lunacia Land', 'LUL', _baseTokenURI)
  {
    address[] memory _minters = new address[](1);
    _minters[0] = msg.sender;
    addMinters(_minters);
  }

  function ownerOfLand(int256 _row, int256 _col) view public returns (address) {
    uint256 tokenId = getTokenId(_row, _col);

    return ownerOf(tokenId);
  }

  function landOfOwner(address _owner) view public returns (int256[] memory, int256[] memory) {
    uint256 len = _ownedTokens[_owner].length;
    int256[] memory rows = new int256[](len);
    int256[] memory cols = new int256[](len);

    for (uint256 i = 0; i < len; i++) {
      (int256 row, int256 col) = decodeTokenId(_ownedTokens[_owner][i]);
      rows[i] = row;
      cols[i] = col;
    }

    return (rows, cols);
  }

  function batchMint(address[] calldata _owners, int256[] calldata _rows, int256[] calldata _cols) external onlyMinter {
    require (_owners.length == _rows.length && _rows.length == _cols.length);

    for (uint256 _i = 0; _i < _owners.length; _i++) {
      mint(_owners[_i], _rows[_i], _cols[_i]);
    }
  }

  function mint(address _to, int256 _row, int256 _col) public onlyMinter returns (uint256 _itemId) {
    _itemId = getTokenId(_row, _col);
    _mint(_to, _itemId);
  }
}
