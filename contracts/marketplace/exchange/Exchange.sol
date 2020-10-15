pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/access/HasAdmin.sol";
import "@axie/contract-library/contracts/token/erc20/IERC20.sol";
import "@axie/contract-library/contracts/token/erc721/IERC721.sol";
import "../auction/AbstractAuction.sol";
import "./IExchange.sol";
import "./ExchangeTokens.sol";


/// @title Exchange for fungible and non-fungible tokens.
contract Exchange is ExchangeTokens {

  bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd; // solium-disable-line uppercase

  // Represents an Listing. An Listing can be viewed as a bundle of FT and NFT tokens.
  struct Listing {
    // Token type.
    TokenType[] tokenTypes;
    // Address of the assets, should be FT or NFT token.
    address[] tokenAddresses;
    // Amount for FT token, tokenId for NFT token.
    uint256[] tokenNumbers;
    // Created time
    uint256 createdAt;
  }

  event ListingCreated(address _creator, uint256 _listingIndex);

  // Collection of listing created.
  Listing[] public listings;

  // Mapping between listings hash and listing index, to prevent duplicated listing.
  mapping(bytes32 => uint256) private listingMap;

  // Collection of supported auction type.
  AbstractAuction[] public auctionTypes;

  constructor(IERC20[] memory _tokens) ExchangeTokens(_tokens) public {
  }

  /// @dev DON'T give me your money.
  function () external {}

  modifier existingAuction(AbstractAuction _auctionType) {
    require(findAuctionTypeIndex(_auctionType) < auctionTypes.length);
    _;
  }

  modifier existingListing(uint256 _listingIndex) {
    require (_listingIndex < listings.length);
    _;
  }

  function addAuctionType(AbstractAuction _auctionType) external onlyAdmin {
    auctionTypes.push(_auctionType);
  }

  function removeAuctionType(uint256 _index) external onlyAdmin {
    require(_index < auctionTypes.length);

    // Replace with the last auctions.
    uint256 _len = auctionTypes.length;
    auctionTypes[_index] = auctionTypes[_len - 1];
    auctionTypes.length--;
  }

  function findAuctionTypeIndex(AbstractAuction _auctionType) internal view returns (uint256 _i) {
    for (_i = 0; _i < auctionTypes.length; _i++) {
      if (auctionTypes[_i] == _auctionType) {
        break;
      }
    }
  }

  function createOrGetListing(
    TokenType[] calldata _tokenTypes,
    address[] calldata _tokenAddresses,
    uint256[] calldata _tokenNumbers
  )
    external
    returns (uint256)
  {
    require(_tokenTypes.length > 0);
    require(_tokenTypes.length == _tokenAddresses.length && _tokenTypes.length == _tokenNumbers.length);

    bytes32 _hash = keccak256(abi.encode(_tokenAddresses, _tokenNumbers));
    if (listingMap[_hash] > 0) {
      return listingMap[_hash] - 1;
    }

    uint256 _listingIndex = listings.length;
    listingMap[_hash] = _listingIndex + 1;

    Listing memory _newListing = Listing(
      new TokenType[](0),
      new address[](0),
      new uint256[](0),
      now
    );

    listings.push(_newListing);

    for (uint256 _i = 0; _i < _tokenTypes.length; _i++) {
      TokenType _tokenType = _tokenTypes[_i];
      address _tokenAddress = _tokenAddresses[_i];
      uint256 _tokenNumber = _tokenNumbers[_i];

      _verifyTokenType(_tokenType, _tokenAddress);

      // Ensure the order of the items in the listing
      if (_i > 0) {
        address _previousAddress = _tokenAddresses[_i - 1];
        uint256 _previousNumber = _tokenNumbers[_i - 1];

        if (_tokenType == TokenType.FT) {
          require(_tokenAddress > _previousAddress);
        }
        require(_tokenAddress > _previousAddress || (_tokenAddress == _previousAddress && _tokenNumber > _previousNumber));
      }

      listings[_listingIndex].tokenTypes.push(_tokenType);
      listings[_listingIndex].tokenAddresses.push(_tokenAddress);
      listings[_listingIndex].tokenNumbers.push(_tokenNumber);
    }

    emit ListingCreated(msg.sender, _listingIndex);
    return _listingIndex;
  }

  function getListing(uint256 _listingIndex)
    external
    view
    existingListing(_listingIndex)
    returns (
      TokenType[] memory _tokenTypes,
      address[] memory _tokenAddresses,
      uint256[] memory _tokenNumbers
    )
  {
    Listing memory _listing = listings[_listingIndex];

    _tokenTypes = _listing.tokenTypes;
    _tokenAddresses = _listing.tokenAddresses;
    _tokenNumbers = _listing.tokenNumbers;
  }

  function canFacilitateListing(address _facilitator, uint256 _listingIndex)
    view
    external
    existingListing(_listingIndex)
    returns (bool _result)
  {
    Listing memory _listing = listings[_listingIndex];

    _result = true;
    for (uint256 _i = 0; _i < _listing.tokenTypes.length; _i++) {
      TokenType _tokenType = _listing.tokenTypes[_i];
      address _tokenAddress = _listing.tokenAddresses[_i];
      uint256 _tokenNumber = _listing.tokenNumbers[_i];

      if (_tokenType == TokenType.FT) {
        _result = _result
          && IERC20(_tokenAddress).balanceOf(_facilitator) >= _tokenNumber
          && IERC20(_tokenAddress).allowance(_facilitator, address(this)) >= _tokenNumber;
      } else {
        _result = _result
          && IERC721(_tokenAddress).ownerOf(_tokenNumber) == _facilitator
          && IERC721(_tokenAddress).isApprovedForAll(_facilitator, address(this));
      }
    }
  }

  function hasEnoughToken(address _bidder, IERC20 _token, uint256 _amount) view external returns (bool _result) {
    return _token.balanceOf(_bidder) >= _amount
      && _token.allowance(_bidder, address(this)) >= _amount;
  }

  function transferAssets(
    uint256 _listingIndex,
    address _seller,
    address _buyer
  )
    external
    existingAuction(AbstractAuction(msg.sender))
  {
    Listing memory _listing = listings[_listingIndex];

    for (uint256 _i = 0; _i < _listing.tokenTypes.length; _i++) {
      TokenType _tokenType = _listing.tokenTypes[_i];
      address _tokenAddress = _listing.tokenAddresses[_i];
      uint256 _tokenNumber = _listing.tokenNumbers[_i];

      if (_tokenType == TokenType.FT) {
        IERC20(_tokenAddress).transferFrom(_seller, _buyer, _tokenNumber);
      } else {
        IERC721(_tokenAddress).transferFrom(_seller, _buyer, _tokenNumber);
      }
    }
  }

  function withdrawToken(address _buyer, IERC20 _token, uint256 _amount) external existingAuction(AbstractAuction(msg.sender)) {
    _token.transferFrom(_buyer, msg.sender, _amount);
  }

  function _verifyTokenType(TokenType _tokenType, address _tokenAddress) internal {
    require(_tokenType == TokenType.FT || _tokenType == TokenType.NFT);

    // Try calling some signature function to verify the correctness.
    if (_tokenType == TokenType.FT) {
      uint256 _0 = IERC20(_tokenAddress).allowance(address(0), address(0));
    } else {
      bool _1 = IERC721(_tokenAddress).isApprovedForAll(address(0), address(0));
    }
  }
}
