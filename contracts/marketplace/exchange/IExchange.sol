pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/token/erc20/IERC20.sol";


contract IExchange {
  enum TokenType { FT, NFT }

  function createOrGetListing( TokenType[] calldata _tokenTypes,
    address[] calldata _tokenAddresses,
    uint256[] calldata _tokenNumbers
  ) external returns (uint256);

  function canFacilitateListing(address _facilitator, uint256 _listingIndex) view external returns (bool _result);

  function hasEnoughToken(address _bidder, IERC20 _token, uint256 _amount) view external returns (bool _result);

  function transferAssets( uint256 _listingIndex, address _seller, address _buyer) external;

  function withdrawToken(address _buyer, IERC20 _token, uint256 _amount) external;

  function isTokenExchangeable(IERC20 _token) public view returns (bool);

  function getListing(uint256 _listingIndex) external view returns (
    TokenType[] memory _tokenTypes,
    address[] memory _tokenAddresses,
    uint256[] memory _tokenNumbers
  );
}
