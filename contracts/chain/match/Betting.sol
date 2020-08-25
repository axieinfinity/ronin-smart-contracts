pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/access/HasAdmin.sol";
import "../common/WETHDev.sol";


contract IBetting is HasAdmin {
  //  event LockedMatchUpdated(uint256 indexed _matchId, bool indexed _locked);
  //  event MatchReviewRequested(uint256 indexed _matchId, address indexed _from);
  event BetPlaced(uint256 indexed _matchId, address indexed _from, uint256 _value);

  //  enum Action {RequestMatchReview, PlaceBet}
  enum MatchStatus {NotCreated, Created, Done}

  // Lock time of rewards
  uint256 public timeDue;

  // Fee to request to review a match
  uint256 public requestMatchReviewFee;

  // Max gamblers in a match
  //    0 - no limit
  uint256 public maxGamblers;

  // Mapping matchId => status
  mapping(uint256 => uint256) matches;

  // Mapping matchId => wager
  mapping(uint256 => uint256) wagers;

  // Mapping matchId => reward
  mapping(uint256 => uint256) rewards;

  // Mapping gambler => reward
  mapping(address => uint256) pendingReward;

  // Mapping matchId => gambler => bool
  mapping(uint256 => mapping(address => bool)) gamblerMark;

  // Mapping matchId => gamblers
  mapping(uint256 => address[]) gamblers;

  // Mapping matchId => locked
  mapping(uint256 => bool) lockedMatches;

  // Token address
  WETHDev public weth;

  //  // ...
  //  function unlock(uint256 _matchId) public onlyAdmin {
  //    lockedMatches[_matchId] = false;
  //    emit LockedMatchUpdated(_matchId, false);
  //  }

  function getGamblers(uint256 _matchId) public view returns (address[] memory) {
    return gamblers[_matchId];
  }


  /**
  *
  **/
    function receiveApproval(
      address _from,
      uint256 _value,
      address _tokenAddress,
      bytes memory /* _data */
    )
    public
    {
      require(address(weth) == _tokenAddress);

      uint256 _action;
      uint256 _matchId;

      assembly {
        _action := calldataload(0xf4)
        _matchId := calldataload(0x124)
      }

      if (Action(_action) == Action.RequestMatchReview) {
        _requestMatchReview(_from, _matchId);
      }

      if (Action(_action) == Action.PlaceBet) {
        _place(_from, _matchId);
      }

      revert("invalid action");
    }

  // Request match review
  function _requestMatchReview(uint256 _matchId, address _from, uint256 _value) internal {
    require(_value == requestMatchReviewFee, "request fee is not enough");
    require(MatchStatus(matches[_matchId]) == MatchStatus.Done);
    require(weth.transferFrom(_from, this, _value));

    lockedMatches[_matchId] = true;

    emit MatchReviewRequested(_matchId, _from);
  }

  // ...
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
    rewards[_matchId] += _value;

    emit BetPlaced(_matchId, _from, _value);
  }
}
