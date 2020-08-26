pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/token/erc20/IERC20Receiver.sol";
import "./IAppeal.sol";

contract Game is IAppeal, IERC20Receiver {
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
    uint256,
    address _tokenAddress,
    bytes memory /* _data */
  ) public
  {
    require(address(weth) == _tokenAddress);

    uint256 _action;
    uint256 _matchId;
    uint256 _joinFee;

    assembly {
      _action := calldataload(0xa4)
      _matchId := calldataload(0xc4)
    }

    if (Action(_action) == Action.Appeal) {
      _appeal(_matchId, _from);
    } else if (Action(_action) == Action.CreateMatch) {
      assembly { _joinFee := calldataload(0xe4) }
      _createMatchAndCharge(_matchId, _from, _joinFee);
    } else if (Action(_action) == Action.JoinMatch) {
      _joinMatchAndCharge(_matchId, _from);
    } else if (Action(_action) == Action.UnjoinMatch) {
      _unjoinMatchAndCharge(_matchId, _from);
    } else {
      revert("invalid action");
    }
  }
}
