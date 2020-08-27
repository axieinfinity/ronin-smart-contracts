pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/math/SafeMath.sol";
import "./IMatch.sol";
import "./IMatchOperation.sol";


contract IReward is IMatchOperation {
  using SafeMath for uint256;

  event RewardTimeDueUpdated(uint256 indexed _rewardTimeDue);

  uint256 public rewardTimeDue;

  modifier onlyUnavaiableReward(uint256 _id) {
    require(!isRewardAvailable(_id));
    _;
  }

  // Mapping player => matchId[]
  mapping(address => uint256[]) pendingMatches;

  function setRewardTimeDue(uint256 _rewardTimeDue) public onlyAdmin {
    require(_rewardTimeDue > 0);
    rewardTimeDue = _rewardTimeDue;
    emit RewardTimeDueUpdated(_rewardTimeDue);
  }

  function setMatchResult(uint256 _matchId, address _winner) public onlyAdmin {
    super._setMatchResult(_matchId, _winner);
    pendingMatches[_winner].push(_matchId);
  }

  function isRewardAvailable(uint256 _matchId) public view returns (bool) {
    uint256 _now = block.timestamp;
    uint256 _doneAt = matchDoneAt[_matchId];

    return _now >= _doneAt.add(rewardTimeDue);
  }

  function getPendingRewards() public view returns (uint256) {
    return getPendingRewardsOf(msg.sender);
  }

  function getPendingRewardsOf(address _to) public view returns (uint256 _rewards) {
    uint256[] memory _matches = pendingMatches[_to];
    uint256 _matchId;

    for (uint256 _i = 0; _i < _matches.length; ++_i) {
      _matchId = _matches[_i];

      if (isRewardAvailable(_matchId)) {
        _rewards = _rewards.add(getMatchRewards(_matchId));
      }
    }

    return _rewards;
  }

  function withdrawPendingRewards() public {
    withdrawPendingRewardsFor(msg.sender);
  }

  function withdrawPendingRewardsFor(address _to) public {
    uint256[] storage _pendingMatches = pendingMatches[_to];

    uint256[] memory _rewardIndexes = new uint256[](_pendingMatches.length);
    uint256 _rewards;
    uint256 _rewardCount;

    uint256 _matchId;
    for (uint256 _i = 0; _i < _pendingMatches.length; ++_i) {
      _matchId = _pendingMatches[_i];

      if (isRewardAvailable(_matchId)) {
        _rewards = _rewards.add(getMatchRewards(_matchId));
        _rewardIndexes[_rewardCount++] = _i;
      }
    }

    require(_rewardCount > 0 && _rewards > 0, "this address has no reward");

    // remove reward matches from pending matches
    uint256 _lastMatchId;
    for (uint256 _i = _rewardCount; _i > 0; --_i) {
      _lastMatchId = _pendingMatches[_pendingMatches.length - 1];
      _pendingMatches[_rewardIndexes[_i - 1]] = _lastMatchId;
      _pendingMatches.length--;
    }

    require(weth.transfer(_to, _rewards));
  }
}
