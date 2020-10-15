pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/math/Math.sol";
import "@axie/contract-library/contracts/math/SafeMath.sol";
import "@axie/contract-library/contracts/token/erc20/IERC20.sol";
import "@axie/contract-library/contracts/util/AddressUtils.sol";
import "../../exchange/IExchange.sol";
import "../AbstractAuction.sol";
import "./IOfferAuction.sol";


contract OfferAuction is AbstractAuction, IOfferAuction {
  using AddressUtils for address;
  using SafeMath for uint256;

  // Represents an offer on a listing.
  struct Offer {
    address offerer;
    uint256 price;
  }

  // Mapping from offerer => listing index => token => offer
  mapping (address => mapping (uint256 => mapping (address => Offer))) public offers;

  constructor(
    Registry _registry,
    uint256 _ownerCut
  )
    public
    AbstractAuction(_registry, _ownerCut)
  {
  }

  function createOffer(
    IExchange.TokenType[] calldata _tokenTypes,
    address[] calldata _tokenAddresses,
    uint256[] calldata _tokenNumbers,
    IERC20 _token,
    uint256 _price
  )
    external
    whenNotPaused
  {
    uint256 _listingIndex = _getExchangeContract().createOrGetListing(
      _tokenTypes,
      _tokenAddresses,
      _tokenNumbers
    );

    createOffer(
      _listingIndex,
      _token,
      _price
    );
  }

  function acceptOffer(
    address _offerer,
    uint256 _listingIndex,
    IERC20 _token,
    uint256 _price
  )
    external
  {
    address _seller = msg.sender;
    IExchange exchange = _getExchangeContract();

    require(exchange.isTokenExchangeable(_token));
    require(exchange.canFacilitateListing(_seller, _listingIndex));

    Offer memory _offer = offers[_offerer][_listingIndex][address(_token)];
    require(_offer.offerer == _offerer && _price <= _offer.price);

    uint256 _totalPrice = _offer.price;
    _removeOffer(_offerer, _token, _listingIndex);

    if (_totalPrice > 0) {
      _getExchangeContract().withdrawToken(_offerer, _token, _totalPrice);

      //  Calculate the offer's cut.
      uint256 _sellerCut = _computeCut(_totalPrice);
      uint256 _sellerProceeds = _totalPrice.sub(_sellerCut);

      _token.transfer(_seller, _sellerProceeds);
    }

    _getExchangeContract().transferAssets(_listingIndex, _seller, _offerer);

    _revalidClockAuction(_listingIndex);

    emit OfferAccepted(
      _seller,
      _offerer,
      _listingIndex,
      _token,
      _totalPrice
    );
  }

  function revalidateOffer(address _offerer, IERC20 _token, uint256 _listingIndex) external {
    Offer memory _offer = offers[_offerer][_listingIndex][address(_token)];

    if (!_getExchangeContract().hasEnoughToken(_offerer, _token, _offer.price)) {
      _cancelOffer(_offerer, _token, _listingIndex);
    }
  }

  function cancelOffer(IERC20 _token, uint256 _listingIndex) external {
    _cancelOffer(msg.sender, _token, _listingIndex);
  }

  function rejectOffer(address _offerer, IERC20 _token, uint256 _listingIndex) external {
    require(_getExchangeContract().canFacilitateListing(msg.sender, _listingIndex));
    _cancelOffer(_offerer, _token, _listingIndex);
  }

  function createOffer(uint256 _listingIndex, IERC20 _token, uint256 _price) public {
    require(_getExchangeContract().isTokenExchangeable(_token));
    require(_getExchangeContract().hasEnoughToken(msg.sender, _token, _price));

    Offer memory _offer = Offer(msg.sender, _price);

    _addOffer(_listingIndex,  _offer, _token);
  }

  function _cancelOffer(address _offerer, IERC20 _token, uint256 _listingIndex) internal {
    _removeOffer(_offerer, _token, _listingIndex);
    emit OfferCanceled(_offerer, _token, _listingIndex);
  }

  function _addOffer(
    uint256 _listingIndex,
    Offer memory _offer,
    IERC20 _token
  )
    internal
  {
    offers[_offer.offerer][_listingIndex][address(_token)] = _offer;

    emit OfferCreated(
      _offer.offerer,
      _listingIndex,
      _token,
      _offer.price
    );
  }

  function _computeCut(uint256 _totalPrice) internal view returns (uint256) {
    return _totalPrice.mul(ownerCut).div(10000);
  }

  function _removeOffer(address _offerer, IERC20 _token, uint256 _listingIndex) internal {
    delete offers[_offerer][_listingIndex][address(_token)];
  }

  function _revalidClockAuction(uint256 _clockListingIndex) internal {
    IExchange exchange = _getExchangeContract();
    IClockAuction clockAuction = _getClockContract();

    (, address[] memory _tokenAddresses, uint256[] memory _tokenNumbers) = exchange.getListing(_clockListingIndex);

    for (uint256 _i; _i < _tokenAddresses.length; _i++) {
      (address[] memory _sellers, uint256[] memory _listingIndexes) =
        clockAuction.getTokenAuctions(_tokenAddresses[_i], _tokenNumbers[_i]);

      require(_sellers.length == _listingIndexes.length);

      for (uint256 _j; _j < _sellers.length; _j++) {
        clockAuction.revalidateAuction(_sellers[_j], _listingIndexes[_j]);
      }
    }
  }
}
