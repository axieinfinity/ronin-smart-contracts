
pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/token/erc20/IERC20.sol";
import "../../exchange/IExchange.sol";


contract IOfferAuction {
  event OfferCreated(
    address _offerer,
    uint256 _listingIndex,
    IERC20 _token,
    uint256 _price
  );

  event OfferAccepted(
    address _seller,
    address _buyer,
    uint256 _listingIndex,
    IERC20 _token,
    uint256 _price
  );

  event OfferCanceled(
    address _offerer,
    IERC20 _token,
    uint256 _listingIndex
  );

  function createOffer(
    IExchange.TokenType[] calldata _tokenTypes,
    address[] calldata _tokenAddresses,
    uint256[] calldata _tokenNumbers,
    IERC20 _token,
    uint256 _price
  ) external;

  function acceptOffer( address _offerer, uint256 _listingIndex, IERC20 _token, uint256 _price) external;
  
  function revalidateOffer(address _offerer, IERC20 _token, uint256 _listingIndex) external; 

  function cancelOffer(IERC20 _token, uint256 _listingIndex) external;

  function rejectOffer(address _offerer, IERC20 _token, uint256 _listingIndex) external;

  function createOffer(uint256 _listingIndex, IERC20 _token, uint256 _price) public;
}
