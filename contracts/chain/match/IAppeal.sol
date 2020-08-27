pragma solidity ^0.5.2;

import "./IReward.sol";


contract IAppeal is IReward {
  event AppealCostUpdated(uint256 indexed _appealCost);
  event MatchAppeal(uint256 _matchId, address _from);
  event MatchResultUpdated(uint256 indexed _matchId, address indexed _winner);

  struct Appeal {
    address _appealer;
    address _lastWinner;
    bool _resolved;
  }

  // Mapping matchId => appealed
  mapping(uint256 => Appeal) appealedMatches;

  uint256 public appealCost;

  modifier onlyNotResolvedAppealed(uint256 _matchId) {
    require(_isMatchHasAppealToResolve(_matchId));
    _;
  }

  modifier onlyNoAppealed(uint256 _matchId) {
    require(_isMatchHasNoAppeal(_matchId));
    _;
  }

  function setAppealCost(uint256 _appealCost) public onlyAdmin {
    appealCost = _appealCost;
    emit AppealCostUpdated(_appealCost);
  }

  function updateMatchResult(uint256 _matchId, address _winner)
    public
    onlyAdmin
    onlyDoneMatch(_matchId)
    onlyNotResolvedAppealed(_matchId)
  {
    address _lastWinner = appealedMatches[_matchId]._lastWinner;

    if (_lastWinner != _winner) {
      address _appealer = appealedMatches[_matchId]._appealer;
      require(weth.transfer(_appealer, appealCost));
    }

    winners[_matchId] = _winner;
    pendingMatches[_winner].push(_matchId);
    appealedMatches[_matchId]._resolved = true;

    emit MatchResultUpdated(_matchId, _winner);
  }

  function cancelMatchResult(uint256 _matchId)
    public
    onlyAdmin
    onlyDoneMatch(_matchId)
    onlyNotResolvedAppealed(_matchId)
  {
    address[] memory _players = players[_matchId];
    for (uint256 _i; _i < _players.length; ++_i) {
      require(weth.transfer(_players[_i], fees[_matchId]));
    }

    address _appealer = appealedMatches[_matchId]._appealer;
    require(weth.transfer(_appealer, appealCost));

    appealedMatches[_matchId]._resolved = true;
    matches[_matchId] = uint256(MatchStatus.Cancelled);

    emit MatchCancelled(_matchId);
  }

  function isRewardAvailable(uint256 _matchId) public view returns (bool) {
    return super.isRewardAvailable(_matchId) && (
      _isMatchHasNoAppeal(_matchId) || _isMatchHasResolvedAppeal(_matchId)
    );
  }

  function appeal(uint256 _matchId) public {
    _appeal(_matchId, msg.sender);
  }

  function _appeal(uint256 _matchId, address _from)
    internal
    onlyDoneMatch(_matchId)
    onlyUnavaiableReward(_matchId)
    onlyNoAppealed(_matchId)
  {
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

    appealedMatches[_matchId] = Appeal(_from, winners[_matchId], false);
    delete winners[_matchId];

    emit MatchAppeal(_matchId, _from);
  }

  function _isMatchHasResolvedAppeal(uint256 _matchId) internal view returns (bool) {
    return appealedMatches[_matchId]._resolved;
  }

  function _isMatchHasAppealToResolve(uint256 _matchId) internal view returns (bool) {
    address _appealer = appealedMatches[_matchId]._appealer;
    address _lastWinner = appealedMatches[_matchId]._lastWinner;
    bool _resolved = appealedMatches[_matchId]._resolved;

    return _appealer != address(0) && _lastWinner != address(0) && !_resolved;
  }

  function _isMatchHasNoAppeal(uint256 _matchId) internal view returns (bool) {
    address _appealer = appealedMatches[_matchId]._appealer;
    address _lastWinner = appealedMatches[_matchId]._lastWinner;
    bool _resolved = appealedMatches[_matchId]._resolved;
    return _appealer == address(0) && _lastWinner == address(0) && !_resolved;
  }
}
