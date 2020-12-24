pragma solidity ^0.5.2;

import "./HasAdmin.sol";


contract HasOperators is HasAdmin {
  event OperatorAdded(address indexed _operator);
  event OperatorRemoved(address indexed _operator);

  address[] public operators;
  mapping (address => bool) public operator;

  modifier onlyOperator {
    require(operator[msg.sender]);
    _;
  }

  function addOperators(address[] memory _addedOperators) public onlyAdmin {
    address _operator;

    for (uint256 i = 0; i < _addedOperators.length; i++) {
      _operator = _addedOperators[i];

      if (!operator[_operator]) {
        operators.push(_operator);
        operator[_operator] = true;
        emit OperatorAdded(_operator);
      }
    }
  }

  function removeOperators(address[] memory _removedOperators) public onlyAdmin {
    address _operator;

    for (uint256 i = 0; i < _removedOperators.length; i++) {
      _operator = _removedOperators[i];

      if (operator[_operator]) {
        operator[_operator] = false;
        emit OperatorRemoved(_operator);
      }
    }

    uint256 i = 0;

    while (i < operators.length) {
      _operator = operators[i];

      if (!operator[_operator]) {
        operators[i] = operators[operators.length - 1];
        delete operators[operators.length - 1];
        operators.length--;
      } else {
        i++;
      }
    }
  }
}
