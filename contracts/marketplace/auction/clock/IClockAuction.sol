pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/token/erc20/IERC20.sol";
import "../../exchange/IExchange.sol";

contract IClockAuction {
  event AuctionCreated(
    address _seller,
    uint256 _listingIndex,
    uint256[] _startingPrices,
    uint256[] _endingPrices,
    IERC20[] _exchangeTokens,
    uint256 _startingTimestamp,
    uint256 _duration
  );

  event AuctionSuccessful(
    address _seller,
    address _buyer,
    uint256 _listingIndex,
    IERC20 _token,
    uint256 _totalPrice
  );

  event AuctionCancelled(address _seller, uint256 _listingIndex);

  function createAuction(
    IExchange.TokenType[] calldata _tokenTypes,
    address[] calldata _tokenAddresses,
    uint256[] calldata _tokenNumbers,
    uint256[] calldata _startingPrices,
    uint256[] calldata _endingPrices,
    IERC20[] calldata _exchangeTokens,
    uint256 _duration
  ) external;

  function settleAuction(
    address _seller,
    IERC20 _token,
    uint256 _bidAmount,
    uint256 _listingIndex
  ) external;

  function cancelAuction(uint256 _listingIndex) external;

  function revalidateAuction(address _seller, uint256 _listingIndex) external;

  function getCurrentPrices(address _seller, uint256 _listingIndex)
    external
    view
    returns (IERC20[] memory _exchangeTokens, uint256[] memory _currentPrices);

  function createAuction(
    uint256 _listingIndex,
    uint256[] memory _startingPrices,
    uint256[] memory _endingPrices,
    IERC20[] memory _exchangeTokens,
    uint256 _duration
  ) public;

  function isAuctionExisting(address _seller, uint256 _listingIndex) public view returns (bool);

  function getTokenAuctions(
    address _tokenAddress,
    uint256 _tokenNumber
  )
    public
    view
    returns (address[] memory, uint256[] memory);
}
