pragma solidity ^0.5.2;

import "./IAppeal.sol";

contract Game is IAppeal {
  enum Action {Appeal, CreateMatch, JoinMatch, UnjoinMatch}

  constructor(
    uint256 _minPlayer,
    uint256 _maxPlayer,
    uint256 _operationCost,
    uint256 _unjoinCost,
    uint256 _appealCost,
    uint256 _rewardTimeDue,
    address _weth
  ) public
  {
    minPlayer = _minPlayer;
    maxPlayer = _maxPlayer;
    operationCost = _operationCost;
    unjoinCost = _unjoinCost;
    appealCost = _appealCost;
    rewardTimeDue = _rewardTimeDue;
    weth = WETHDev(_weth);
  }

  function receiveApproval(
    address _from,
    uint256 _value,
    address _tokenAddress,
    bytes memory /* _data */
  ) public
  {
    require(address(weth) == _tokenAddress);

    uint256 _action;
    uint256 _matchId;
    uint256 _value;

    assembly {
      _action := calldataload(0xf4)
      _matchId := calldataload(0x124)
    }

    if (Action(_action) == Action.Appeal) {
      _appeal(_matchId, _from);
    } else if (Action(_action) == Action.CreateMatch) {
      assembly {_value := calldataload(0x144)}
      _createMatchAndCharge(_matchId, _from, _value);
    } else if (Action(_action) == Action.JoinMatch) {
      _joinMatchAndCharge(_matchId, _from);
    } else if (Action(_action) == Action.UnjoinMatch) {
      _unjoinMatchAndCharge(_matchId, _from);
    }

    revert("invalid action");
  }
}
