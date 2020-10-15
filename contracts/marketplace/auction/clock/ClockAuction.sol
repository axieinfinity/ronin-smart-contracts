
pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/math/Math.sol";
import "@axie/contract-library/contracts/math/SafeMath.sol";
import "@axie/contract-library/contracts/util/AddressUtils.sol";
import "../../exchange/IExchange.sol";
import "../AbstractAuction.sol";
import "./TokenAuction.sol";


contract ClockAuction is AbstractAuction, TokenAuction {
  using AddressUtils for address;
  using SafeMath for uint256;

  // Represents an auction on a listing.
  struct Auction {
    // Current seller of the listing.
    address seller;
    // Price (in wei) at beginning of auction.
    uint256[] startingPrices;
    // Price (in wei) at end of auction.
    uint256[] endingPrices;
    // Token allowed to perform auction.
    IERC20[] exchangeTokens;
    // Duration (in seconds) of auction.
    uint256 duration;
    // Time when auction started.
    // NOTE: 0 if this auction has been concluded.
    uint256 startedAt;
  }

  // Mapping from seller => listing index => auction, one listing can have multiple sellers.
  mapping (address => mapping (uint256 => Auction)) public auctions;

  modifier existingAuction(address _seller, uint256 _listingIndex) {
    require(isAuctionExisting(_seller, _listingIndex));
    _;
  }

  constructor(
    uint256 _tokenMaxOccurrences,
    Registry _registry,
    uint256 _ownerCut
  )
    public
    AbstractAuction(_registry, _ownerCut)
  {
    setTokenMaxOccurrences(_tokenMaxOccurrences);
  }

  function createAuction(
    IExchange.TokenType[] calldata _tokenTypes,
    address[] calldata _tokenAddresses,
    uint256[] calldata _tokenNumbers,
    uint256[] calldata _startingPrices,
    uint256[] calldata _endingPrices,
    IERC20[] calldata _exchangeTokens,
    uint256 _duration
  )
    external
    whenNotPaused
  {
    uint256 _listingIndex = _getExchangeContract().createOrGetListing(_tokenTypes, _tokenAddresses, _tokenNumbers);
    createAuction(
      _listingIndex,
      _startingPrices,
      _endingPrices,
      _exchangeTokens,
      _duration
    );
  }

  function settleAuction(
    address _seller,
    IERC20 _token,
    uint256 _bidAmount,
    uint256 _listingIndex
  )
    existingAuction(_seller, _listingIndex)
    external
  {
    require(_isValidSettleToken(_token, _seller, _listingIndex));

    address _buyer = msg.sender;
    Auction storage _auction = auctions[_seller][_listingIndex];

    // Check that the incoming bid is higher than the current price.
    uint256 _totalPrice = _getCurrentPrice(_auction, _token);
    require(_bidAmount >= _totalPrice);

    // The bid is good! Remove the auction before sending the fees
    // to the sender so we can't have a reentrancy attack.
    _removeAuction(_seller, _listingIndex);

    // Transfer proceeds to seller (if there are any!)
    if (_totalPrice > 0) {
      _getExchangeContract().withdrawToken(_buyer, _token, _totalPrice);

      //  Calculate the auctioneer's cut.
      uint256 _auctioneerCut = _computeCut(_totalPrice);
      uint256 _sellerProceeds = _totalPrice.sub(_auctioneerCut);

      _token.transfer(_seller, _sellerProceeds);
    }

    _getExchangeContract().transferAssets(_listingIndex, _seller, _buyer);

    emit AuctionSuccessful(
      _seller,
      _buyer,
      _listingIndex,
      _token,
      _totalPrice
    );
  }

  function cancelAuction(uint256 _listingIndex) external {
    Auction memory _auction = auctions[msg.sender][_listingIndex];
    require(msg.sender == _auction.seller);

    _cancelAuction(msg.sender, _listingIndex);
  }

  function revalidateAuction(address _seller, uint256 _listingIndex) existingAuction(_seller, _listingIndex) external {
    if (!_getExchangeContract().canFacilitateListing(_seller, _listingIndex)) {
      _cancelAuction(_seller, _listingIndex);
    }
  }

  function getCurrentPrices(
    address _seller,
    uint256 _listingIndex
  )
    existingAuction(_seller, _listingIndex)
    external
    view
    returns (IERC20[] memory, uint256[] memory) {
    return _getCurrentPrices(auctions[_seller][_listingIndex]);
  }

  function createAuction(
    uint256 _listingIndex,
    uint256[] memory _startingPrices,
    uint256[] memory _endingPrices,
    IERC20[] memory _exchangeTokens,
    uint256 _duration
  )
    public
    whenNotPaused
  {
    require(_startingPrices.length > 0);
    require(_startingPrices.length == _endingPrices.length && _endingPrices.length == _exchangeTokens.length);

    for (uint256 _i; _i < _exchangeTokens.length; _i++) {
      require(_getExchangeContract().isTokenExchangeable(_exchangeTokens[_i]));
    }

    require(_getExchangeContract().canFacilitateListing(msg.sender, _listingIndex));

    Auction memory _auction = Auction(
      msg.sender,
      _startingPrices,
      _endingPrices,
      _exchangeTokens,
      _duration,
      now
    );

    _addAuction(
      _listingIndex,
      _auction
    );
  }

  function isAuctionExisting(address _seller, uint256 _listingIndex) public view returns (bool) {
    Auction memory _auction = auctions[_seller][_listingIndex];
    return _auction.seller == _seller && _auction.startedAt > 0;
  }

  function _addAuction(
    uint256 _listingIndex,
    Auction memory _auction
  )
    internal
  {
    require(!isAuctionExisting(_auction.seller, _listingIndex));
    // Require that all auctions have a duration of
    // at least one minute. (Keeps our math from getting hairy!).
    require(_auction.duration >= 1 minutes);

    auctions[_auction.seller][_listingIndex] = _auction;

    (, address[] memory _tokenAddresses, uint256[] memory _tokenNumbers) =
      _getExchangeContract().getListing(_listingIndex);

    for (uint256 _i; _i < _tokenAddresses.length; _i++) {
      _addOccurrence(_tokenAddresses[_i], _tokenNumbers[_i], _auction.seller, _listingIndex);
    }

    emit AuctionCreated(
      _auction.seller,
      _listingIndex,
      _auction.startingPrices,
      _auction.endingPrices,
      _auction.exchangeTokens,
      _auction.startedAt,
      _auction.duration
    );
  }

  function _cancelAuction(address _seller, uint256 _listingIndex) internal {
    _removeAuction(_seller, _listingIndex);
    emit AuctionCancelled(_seller, _listingIndex);
  }

  function _removeAuction(address _seller, uint256 _listingIndex) internal {
    (, address[] memory _tokenAddresses, uint256[] memory _tokenNumbers) =
      _getExchangeContract().getListing(_listingIndex);

    for (uint256 _i; _i < _tokenAddresses.length; _i++) {
      _removeOccurrence(_tokenAddresses[_i], _tokenNumbers[_i], _seller, _listingIndex);
    }
    
    delete auctions[_seller][_listingIndex];
  }

  function _getCurrentPrice(
    Auction storage _auction,
    IERC20 _token
  )
    internal
    view
    returns (uint256)
  {
    (IERC20[] memory _exchangeTokens, uint256[] memory _currentPrices) = _getCurrentPrices(_auction);
    uint256 _index = _exchangeTokens.length;

    for (uint256 _i; _i < _exchangeTokens.length; _i++) {
      if (_token == _exchangeTokens[_i]) {
        _index = _i;
        break;
      }
    }

    require(_index < _exchangeTokens.length);

    return _currentPrices[_index];
  }

  function _getCurrentPrices(
    Auction storage _auction
  )
    internal
    view
    returns (IERC20[] storage _exchangeTokens, uint256[] memory _currentPrices)
  {
    uint256 _secondsPassed = 0;

    if (now > _auction.startedAt) {
      _secondsPassed = now.sub(_auction.startedAt);
    }

    _exchangeTokens = _auction.exchangeTokens;
    _currentPrices = _computeCurrentPrices(
      _auction.startingPrices,
      _auction.endingPrices,
      _auction.duration,
      _secondsPassed
    );
  }

  function _computeCurrentPrices(
    uint256[] memory _startingPrices,
    uint256[] memory _endingPrices,
    uint256 _duration,
    uint256 _secondsPassed
  )
    internal
    pure
    returns (uint256[] memory)
  {
    uint256[] memory _prices = new uint256[](_startingPrices.length);

    for (uint256 i; i < _startingPrices.length; ++i) {
     _prices[i] = _computeCurrentPrice(
       _startingPrices[i],
       _endingPrices[i],
       _duration,
       _secondsPassed
      );
    }

    return _prices;
  }

  function _computeCurrentPrice(
    uint256 _startingPrice,
    uint256 _endingPrice,
    uint256 _duration,
    uint256 _secondsPassed
  )
    internal
    pure
    returns (uint256 _currentPrice)
  {
    if (_secondsPassed >= _duration) {
      // We've reached the end of the dynamic pricing portion
      // of the auction, just return the end price.
      _currentPrice = _endingPrice;
    } else {
      uint256 _totalPriceChange = Math.max(_startingPrice, _endingPrice).sub(Math.min(_startingPrice, _endingPrice));

      uint256 _currentPriceChange = _totalPriceChange.mul(_secondsPassed).div(_duration);

      if (_startingPrice < _endingPrice) {
        _currentPrice = _startingPrice.add(_currentPriceChange);
      } else {
        _currentPrice = _startingPrice.sub(_currentPriceChange);
      }
    }
  }

  function _isValidSettleToken(IERC20 _token, address _seller, uint256 _listingIndex) internal view returns (bool) {
    Auction memory _auction = auctions[_seller][_listingIndex];
    uint256 _index = _auction.exchangeTokens.length;

    for (uint256 _i; _i < _auction.exchangeTokens.length; _i++) {
      if (_auction.exchangeTokens[_i] == _token) {
        _index = _i;
        break;
      }
    }

    return _index < _auction.exchangeTokens.length;
  }

  function _computeCut(uint256 _totalPrice) internal view returns (uint256) {
    return _totalPrice.mul(ownerCut).div(10000);
  }
}
