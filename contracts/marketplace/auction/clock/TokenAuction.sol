pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/access/HasAdmin.sol";
import "@axie/contract-library/contracts/token/erc20/IERC20.sol";
import "./IClockAuction.sol";

contract TokenAuction is HasAdmin, IClockAuction {
  struct AuctionBrief {
    address seller;
    uint256 listingIndex;
  }

  // Mapping from token address => listing index => token occurrences
  mapping(address => mapping(uint256 => uint256)) tokenOccurrences;

  // Mapping from token address => token number => array of auction brief
  mapping(address => mapping(uint256 => AuctionBrief[])) tokenAuctionBriefs;

  uint256 tokenMaxOccurrences;

  function getTokenMaxOccurrences() public view returns (uint256) {
    return tokenMaxOccurrences;
  }

  function setTokenMaxOccurrences(uint256 _tokenMaxOccurrences) public onlyAdmin {
    require(_tokenMaxOccurrences > 0);
    tokenMaxOccurrences = _tokenMaxOccurrences;
  }

  function getTokenAuctions(
    address _tokenAddress,
    uint256 _tokenNumber
  )
    public
    view
    returns (address[] memory _sellers, uint256[] memory _listingIndexes)
  {
    uint256 num = tokenOccurrences[_tokenAddress][_tokenNumber];

    _sellers = new address[](num);
    _listingIndexes = new uint256[](num);

    for (uint256 _i; _i < num; _i++) {
      _sellers[_i] = tokenAuctionBriefs[_tokenAddress][_tokenNumber][_i].seller;
      _listingIndexes[_i] = tokenAuctionBriefs[_tokenAddress][_tokenNumber][_i].listingIndex;
    }
  }

  function _addOccurrence(address _tokenAddress, uint256 _tokenNumber, address _seller, uint256 _listingIndex) internal {
    AuctionBrief memory _auctionBrief = AuctionBrief(_seller, _listingIndex);

    tokenAuctionBriefs[_tokenAddress][_tokenNumber].push(_auctionBrief);
    tokenOccurrences[_tokenAddress][_tokenNumber]++;
    require(tokenOccurrences[_tokenAddress][_tokenNumber] <= tokenMaxOccurrences);
  }

  function _removeOccurrence(address _tokenAddress, uint256 _tokenNumber, address _seller, uint256 _listingIndex) internal {
    AuctionBrief[] storage _auctionBriefs = tokenAuctionBriefs[_tokenAddress][_tokenNumber];

    uint256 _index = _auctionBriefs.length;
    AuctionBrief memory _lastAuctionBrief = _auctionBriefs[_auctionBriefs.length - 1];

    for (uint256 _i; _i < tokenOccurrences[_tokenAddress][_tokenNumber]; _i++) {
      if (_auctionBriefs[_i].seller == _seller && _auctionBriefs[_i].listingIndex == _listingIndex) {
        _index = _i;
        break;
      }
    }

    require(_index < _auctionBriefs.length); 

    _auctionBriefs[_index] = _lastAuctionBrief;
    _auctionBriefs.length--;
    tokenOccurrences[_tokenAddress][_tokenNumber]--; 
  }
}
