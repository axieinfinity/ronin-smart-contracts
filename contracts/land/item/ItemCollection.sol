pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/access/HasMinters.sol";
import "@axie/contract-library/contracts/token/erc721/ERC721FullPausable.sol";


contract ItemCollection is HasMinters, ERC721FullPausable {

  struct TokenMetadata {
    string name;
    string symbol;
    string baseTokenURI;
  }

  TokenMetadata[] public tokenMetadata;
  uint256[] public tokenBalance;

  constructor(
    string memory _name,
    string memory _symbol,
    string memory _baseTokenURI
  )
    public
    ERC721FullPausable(_name, _symbol, _baseTokenURI)
  {
    address[] memory _minters = new address[](1);
    _minters[0] = msg.sender;
    addMinters(_minters);
    _addTokenType(_name, _symbol, _baseTokenURI);
  }

  modifier onlyValidTokenType(uint256 _tokenType) {
    require(0 < _tokenType && _tokenType < tokenMetadata.length);
    _;
  }

  function getTokenTypeCount() view public returns (uint256) {
    return tokenMetadata.length - 1;
  }

  function addTokenType(
    string calldata _name,
    string calldata _symbol,
    string calldata _baseTokenURI
  )
    external
    onlyAdmin
    returns (uint256 _tokenType)
  {
    _tokenType = tokenMetadata.length;
    _addTokenType(_name, _symbol, _baseTokenURI);
  }

  function editTokenMetadata(
    uint256 _tokenType,
    string calldata _name,
    string calldata _symbol,
    string calldata _baseTokenURI
  )
    external
    onlyAdmin
    onlyValidTokenType(_tokenType)
  {
    tokenMetadata[_tokenType] = TokenMetadata(
      _name,
      _symbol,
      _baseTokenURI
    );
  }

  function batchMint(
    address[] calldata _recipients,
    uint256[] calldata _tokenTypes,
    uint256[] calldata _tokenIds
  ) external onlyMinter {
    require(_recipients.length == _tokenTypes.length && _tokenTypes.length == _tokenIds.length);

    for (uint256 _i = 0; _i < _recipients.length; _i++) {
      mint(_recipients[_i], _tokenTypes[_i], _tokenIds[_i]);
    }
  }

  function mintNew(address _to, uint256 _tokenType) public onlyMinter onlyValidTokenType(_tokenType) {
    uint256 _tokenId = ++tokenBalance[_tokenType];

    uint256 _itemId = getItemId(_tokenType, _tokenId);
    _mint(_to, _itemId);
  }

  function mint(address _to, uint256 _tokenType, uint256 _tokenId) public onlyMinter onlyValidTokenType(_tokenType) {
    if (_tokenId > tokenBalance[_tokenType]) {
      tokenBalance[_tokenType] = _tokenId;
    }

    uint256 _itemId = getItemId(_tokenType, _tokenId);
    _mint(_to, _itemId);
  }

  function getItemId(uint256 _tokenType, uint256 _tokenId) view public onlyValidTokenType(_tokenType) returns (uint256) {
    require(0 < _tokenId && _tokenId <= tokenBalance[_tokenType]);

    return (_tokenType << 128) | _tokenId;
  }

  function deconstructItemId(uint256 _itemId) pure public returns (uint256 _tokenType, uint256 _tokenId) {
    _tokenType = _itemId >> 128;
    _tokenId = (_itemId << 128) >> 128;
  }

  function _addTokenType(
    string memory _name,
    string memory _symbol,
    string memory _baseTokenURI
  ) internal {
    tokenMetadata.push(
      TokenMetadata(
        _name,
        _symbol,
        _baseTokenURI
      )
    );
    tokenBalance.push(0);
  }
}
