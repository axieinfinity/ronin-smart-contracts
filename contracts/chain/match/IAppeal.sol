pragma solidity ^0.4.0;

import "./IReward.sol";


contract IAppeal is IReward {
  event AppealCostUpdated(uint256 indexed _appealCost);
  event MatchAppeal(uint256 _matchId, address _from);
  event MatchResultUpdated(uint256 indexed _matchId, uint256 indexed _winner);

  uint256 public appealCost;

  function setAppealCost(uint256 _appealCost) public onlyAdmin {
    appealCost = _appealCost;
    emit AppealCostUpdated(_appealCost);
  }

  function updateMatchResult(uint256 _matchId, address _winner) public onlyAdmin {
    winners[_matchId] = _winner;
    pendingMatches[_winner].push(_matchId);

    emit MatchResultUpdated(_matchId, _winner);
  }

  function appeal(uint256 _matchId) public {
    _appeal(_matchId, msg.sender);
  }

  function _appeal(uint256 _matchId, address _from) internal {
    require(weth.transferFrom(_from, this, appealCost));
    require(MatchStatus(matches[_matchId]) == MatchStatus.Done);

    // Remove matchId from pendingMatches of winner
    address _winner = winners[_matchId];
    uint256[] memory _pendingMatches = pendingMatches[_winner];

    uint256 _index;
    for (uint256 _i = 0; _i < _pendingMatches.length; ++i) {
      if (_pendingMatches[i] == _matchId) {
        _index = _i;
      }
    }

    _pendingMatches[_index] = _pendingMatches[_pendingMatches.length - 1];
    _pendingMatches.length--;

    delete winners[_matchId];

    emit MatchAppeal(_matchId, _from);
  }
}
