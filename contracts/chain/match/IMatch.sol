pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/access/HasAdmin.sol";


contract IMatch is HasAdmin {
  enum MatchStatus {NotCreated, Created, Done, Cancelled}

  event PlayerThresholdUpdated(uint256 indexed _minPlayer, uint256 indexed _maxPlayer);

  event MatchCreated(uint256 indexed _matchId);
  event MatchCancelled(uint256 indexed _matchId);
  event MatchDone(uint256 indexed _matchId, address indexed _winner);

  event PlayerJoined(uint256 indexed _matchId, address indexed _player);
  event PlayerUnjoined(uint256 indexed _matchId, address indexed _player);

  uint256 public minPlayer;
  uint256 public maxPlayer;

  // Mapping matchId => status
  mapping(uint256 => uint256) matches;

  // Mapping matchId => updatedAt
  mapping(uint256 => uint) matchDoneAt;

  // Mapping matchId => player => bool
  mapping(uint256 => mapping(address => bool)) playerMark;

  // Mapping matchId => player
  mapping(uint256 => address[]) players;

  // Mapping matchId => player
  mapping(uint256 => address) winners;

  modifier onlyCreated(uint256 _id) {
    require(MatchStatus(matches[_id]) == MatchStatus.Created);
    _;
  }

  function setPlayerThreshold(uint256 _minPlayer, uint256 _maxPlayer) public onlyAdmin {
    require(0 < _maxPlayer);
    require(_minPlayer < _maxPlayer);

    minPlayer = _minPlayer;
    maxPlayer = _maxPlayer;

    emit PlayerThresholdUpdated(_minPlayer, _maxPlayer);
  }

  function _setMatchResult(uint256 _matchId, address _winner) internal onlyCreated(_matchId) {
    require(_getTotalPlayer(_matchId) <= maxPlayer);
    require(minPlayer <= _getTotalPlayer(_matchId));

    matches[_matchId] = uint256(MatchStatus.Done);
    winners[_matchId] = _winner;
    matchDoneAt[_matchId] = block.timestamp;

    emit MatchDone(_matchId, _winner);
  }

  function _getTotalPlayer(uint256 _matchId) internal view returns (uint256) {
    return players[_matchId].length;
  }

  function _createMatch(uint256 _matchId, address _from) internal {
    require(MatchStatus(matches[_matchId]) == MatchStatus.NotCreated, "this match is created");

    matches[_matchId] = uint256(MatchStatus.Created);
    _joinMatch(_matchId, _from);

    emit MatchCreated(_matchId);
  }

  function _joinMatch(uint256 _matchId, address _from) internal onlyCreated(_matchId) {
    require(players[_matchId].length < maxPlayer, "this match is full");
    require(!playerMark[_matchId][_from], "this player has already joined the match");

    players[_matchId].push(_from);
    playerMark[_matchId][_from] = true;

    emit PlayerJoined(_matchId, _from);
  }

  function _unjoinMatch(uint256 _matchId, address _from) internal onlyCreated(_matchId) {
    require(playerMark[_matchId][_from], "this player has not joined the match");

    uint256 _index;
    uint256 _totalPlayer = _getTotalPlayer(_matchId);
    address[] storage _players = players[_matchId];

    for (uint256 _i = 0; _i < _totalPlayer; _i++) {
      if (players[_matchId][_i] == _from) {
        _index = _i;
      }
    }

    address lastPlayer = players[_matchId][_totalPlayer - 1];

    _players[_index] = lastPlayer;
    _players.length--;
    playerMark[_matchId][_from] = false;

    emit PlayerUnjoined(_matchId, _from);

    if (_players.length == 0) {
      matches[_matchId] = uint256(MatchStatus.Cancelled);
      emit MatchCancelled(_matchId);
    }
  }
}
