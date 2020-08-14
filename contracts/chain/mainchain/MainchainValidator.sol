pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/access/HasAdmin.sol";
import "../common/Validator.sol";


/**
 * @title Validator
 * @dev Simple validator contract
 */
contract MainchainValidator is Validator, HasAdmin {
  constructor(
    address[] memory _validators,
    uint256 _num,
    uint256 _denom
  ) Validator(_validators, _num, _denom) public {
  }

  function addValidators(address[] calldata _validators) external onlyAdmin {
    for (uint256 _i; _i < _validators.length; ++_i) {
      _addValidator(_validators[_i]);
    }
  }

  function removeValidator(uint256 _index) external onlyAdmin {
    _removeValidator(_index);
  }

  function updateQuorum(uint256 _numerator, uint256 _denominator) external onlyAdmin {
    _updateQuorum(_numerator, _denominator);
  }
}
