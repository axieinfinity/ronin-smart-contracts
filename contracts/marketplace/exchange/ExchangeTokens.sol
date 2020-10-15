pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/access/HasAdmin.sol";
import "@axie/contract-library/contracts/token/erc20/IERC20.sol";
import "./IExchange.sol";


contract ExchangeTokens is IExchange, HasAdmin {
  IERC20[] public exchangeTokens;
  mapping(address => bool) public exchangeTokenMap;
  uint256 public exchangeTokenCount;

  event TokenAdded(IERC20 _token);
  event TokenRemoved(IERC20 _token);

  constructor(IERC20[] memory _tokens) public {
    addTokens(_tokens);
  }

  function addTokens(IERC20[] memory _tokens) public onlyAdmin {
    for (uint256 _i; _i < _tokens.length; ++_i) {
      _addToken(_tokens[_i]);
    }
  }

  function removeToken(IERC20 _token) public onlyAdmin {
    _removeToken(_token);
  }

  function isTokenExchangeable(IERC20 _token) public view returns (bool) {
    return exchangeTokenMap[address(_token)];
  }

  function _addToken(IERC20 _token) internal {
    require(!exchangeTokenMap[address(_token)]);

    exchangeTokens.push(_token);
    exchangeTokenMap[address(_token)] = true;
    exchangeTokenCount++;

    emit TokenAdded(_token);
  }

  function _removeToken(IERC20 _token) internal {
    require(exchangeTokenMap[address(_token)]);

    uint256 _index;
    IERC20 _lastToken = exchangeTokens[exchangeTokenCount - 1];

    for (uint256 _i = 0; _i < exchangeTokenCount; _i++) {
      if (exchangeTokens[_i] == _token) {
        _index = _i;
        break;
      }
    }

    exchangeTokenMap[address(_token)] = false;

    exchangeTokens[_index] = _lastToken;
    exchangeTokens.length--;
    exchangeTokenCount--;

    emit TokenRemoved(_token);
  }
}
