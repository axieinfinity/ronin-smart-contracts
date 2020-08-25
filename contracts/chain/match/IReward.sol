pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/math/SafeMath.sol";
import "./IMatch.sol";
import "./IMatchOperation.sol";


contract IReward is IMatchOperation {
  using SafeMath for uint256;

  event RewardTimeDueUpdated(uint256 indexed _rewardTimeDue);

  uint256 public rewardTimeDue; // in days

  // Mapping player => matchId[]
  mapping(address => uint256[]) pendingMatches;

  function setRewardTimeDue(uint256 _rewardTimeDue) public onlyAdmin {
    require(_rewardTimeDue > 0);
    rewardTimeDue = _rewardTimeDue;
    emit RewardTimeDueUpdated(_rewardTimeDue);
  }

  function setMatchResult(uint256 _matchId, uint256 _winner) public onlyAdmin {
    super._setMatchResult(_matchId, _winner);
    pendingMatches[_winner].push(_matchId);
  }

  function withdrawPendingRewards() public {
    withdrawPendingRewardsFor(msg.sender);
  }

  function withdrawPendingRewardsFor(address _to) public {
    uint256 _rewards = getPendingRewardsOf(_to);
    delete pendingMatches[_to];

    require(weth.transferFrom(this, _to, _rewards));
  }

  function getPendingRewards() public view returns (uint256)  {
    return getPendingRewardsOf(msg.sender);
  }

  function getPendingRewardsOf(address _player) public view returns (uint256 _rewards) {
    uint256 _matches = pendingMatches[_player];
    uint256 _matchId;
    uint256 _updatedAt;

    for (uint256 _i = 0; _i < _matches.length; ++i) {
      _matchId = _matches[_i];
      _updatedAt = matchDoneAt[_matchId];

      if (_getElapsedDays(_updatedAt) >= rewardTimeDue) {
        _rewards = _rewards.add(getMatchRewards(_matchId));
      }
    }

    return _rewards;
  }

  function _getElapsedDays(uint256 _time) internal view returns (uint256) {
    uint256 _now = block.timestamp;
    return _now.sub(_time).div(uint256(60)).div(uint256(60)).div(uint256(24));
  }
}
