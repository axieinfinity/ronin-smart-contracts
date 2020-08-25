pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/access/HasAdmin.sol";
import "@axie/contract-library/contracts/math/SafeMath.sol";
import "../common/WETHDev.sol";


contract IBetting is HasAdmin {
  using SafeMath for uint256;

  event BetPlaced(uint256 indexed _matchId, address indexed _from, uint256 _value);
  event MatchResultUpdated(uint256 indexed _updateAt, address indexed _winner);

  enum MatchStatus {NotCreated, Created, Done}

  // Max gamblers in a match
  uint256 public maxGamblers;

  // Mapping matchId => status
  mapping(uint256 => uint256) matches;

  // Mapping matchId => updatedAt
  mapping(uint256 => uint) matchResultUpdatedAt;

  // Mapping matchId => wager
  mapping(uint256 => uint256) wagers;

  // Mapping matchId => reward
  mapping(uint256 => uint256) rewards;

  // Mapping matchId => gambler => bool
  mapping(uint256 => mapping(address => bool)) gamblerMark;

  // Mapping matchId => gamblers
  mapping(uint256 => address[]) gamblers;

  // Token address
  WETHDev public weth;


  function getGamblers(uint256 _matchId) public view returns (address[] memory) {
    return gamblers[_matchId];
  }

  function getRewards(uint256 _matchId) public view returns (uint256) {
    return wagers[_matchId].mul(uint256(gamblers[_matchId].length));
  }

  function updateMatchResult(uint256 _matchId, address _winner) public onlyAdmin {
    require(MatchStatus(matches[_matchId]) != MatchStatus.NotCreated);

    matchResultUpdatedAt[_matchId] = now;
    winners[_matchId] = _winner;

    emit MatchResultUpdated(matchResultUpdatedAt[_matchId], _winner);
  }

  function _placeBet(uint256 _matchId, address _from, uint256 _value) internal {
    if (MatchStatus(matches[_matchId]) == MatchStatus.NotCreated) {
      matches[_matchId] = uint256(MatchStatus.Created);
      wagers[_matchId] = _value;
    }

    require(MatchStatus(matches[_matchId]) == MatchStatus.Created);
    require(gamblers[_matchId].length < maxGamblers, "enough gambler");
    require(!gamblerMark[_matchId][_from], "this gambler has already placed bet");
    require(_value == wagers[_matchId], "wager is not enough");

    require(weth.transferFrom(_from, this, _value));

    gamblers[_matchId].push(_from);
    gamblerMark[_matchId][_from] = true;

    emit BetPlaced(_matchId, _from, _value);
  }
}
