pragma solidity ^0.5.2;

import "./IReward.sol";


contract IAppeal is IReward {
  event AppealCostUpdated(uint256 indexed _appealCost);
  event MatchAppeal(uint256 _matchId, address _from);
  event MatchResultUpdated(uint256 indexed _matchId, address indexed _winner);

  uint256 public appealCost;

  // Mapping matchId => appealed
  mapping(uint256 => bool) appealedMatches;

  function setAppealCost(uint256 _appealCost) public onlyAdmin {
    appealCost = _appealCost;
    emit AppealCostUpdated(_appealCost);
  }

  function updateMatchResult(uint256 _matchId, address _winner) public onlyAdmin {
    winners[_matchId] = _winner;
    pendingMatches[_winner].push(_matchId);
    appealedMatches[_matchId] = false;

    emit MatchResultUpdated(_matchId, _winner);
  }

  function isRewardAvailable(uint256 _matchId) public view returns (bool) {
    return super.isRewardAvailable(_matchId) && !appealedMatches[_matchId];
  }

  function appeal(uint256 _matchId) public {
    _appeal(_matchId, msg.sender);
  }

  function _appeal(uint256 _matchId, address _from) internal {
    require(MatchStatus(matches[_matchId]) == MatchStatus.Done);
    require(!appealedMatches[_matchId]);
    require(weth.transferFrom(_from, address(this), appealCost));

    // Remove matchId from pendingMatches of winner
    address _winner = winners[_matchId];
    uint256[] storage _pendingMatches = pendingMatches[_winner];

    uint256 _index;
    for (uint256 _i = 0; _i < _pendingMatches.length; ++_i) {
      if (_pendingMatches[_i] == _matchId) {
        _index = _i;
      }
    }

    _pendingMatches[_index] = _pendingMatches[_pendingMatches.length - 1];
    _pendingMatches.length--;

    delete winners[_matchId];
    appealedMatches[_matchId] = true;

    emit MatchAppeal(_matchId, _from);
  }
}
