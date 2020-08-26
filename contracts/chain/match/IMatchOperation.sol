pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/math/SafeMath.sol";
import "../common/WETHDev.sol";
import "./IMatch.sol";


contract IMatchOperation is IMatch {
  using SafeMath for uint256;

  event OperationCostUpdated(uint256 indexed _operationCost);

  WETHDev public weth;

  uint256 public operationCost;
  uint256 public unjoinCost;

  // Mapping matchId => join fee
  mapping(uint256 => uint256) fees;

  function getMatchRewards(uint256 _matchId) public view returns (uint256) {
    uint256 _total = fees[_matchId].mul(getTotalPlayer(_matchId));
    return _total.sub(operationCost);
  }

  function setOperationCost(uint256 _operationCost) public onlyAdmin {
    operationCost = _operationCost;
    emit OperationCostUpdated(operationCost);
  }

  function transferWETHTo(address _to, uint256 _value) public onlyAdmin {
    require(weth.transfer(_to, _value));
  }

  function createMatchAndCharge(uint256 _matchId, uint256 _value) public {
    _createMatchAndCharge(_matchId, msg.sender, _value);
  }

  function joinMatchAndCharge(uint256 _matchId) public {
    _joinMatchAndCharge(_matchId, msg.sender);
  }

  function unjoinMatchAndCharge(uint256 _matchId) public {
    _unjoinMatchAndCharge(_matchId, msg.sender);
  }

  function _createMatchAndCharge(uint256 _matchId, address _from, uint256 _value) internal {
    require(operationCost < _value.mul(maxPlayer));
    require(unjoinCost < _value);
    require(weth.transferFrom(_from, address(this), _value));

    fees[_matchId] = _value;
    _createMatch(_matchId, _from);
  }

  function _joinMatchAndCharge(uint256 _matchId, address _from) internal {
    require(weth.transferFrom(_from, address(this), fees[_matchId]));
    _joinMatch(_matchId, _from);
  }

  function _unjoinMatchAndCharge(uint256 _matchId, address _from) internal {
    require(weth.transfer(_from, fees[_matchId].sub(unjoinCost)));
    _unjoinMatch(_matchId, _from);
  }
}
