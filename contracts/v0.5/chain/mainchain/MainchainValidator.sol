// SPDX-License-Identifier: MIT
pragma solidity ^0.5.17;

import "../../references/HasAdmin.sol";
import "../common/Validator.sol";

/**
 * @title Validator
 * @dev Simple validator contract
 */
contract MainchainValidator is Validator, HasAdmin {
  uint256 nonce;

  constructor(
    address[] memory _validators,
    uint256 _num,
    uint256 _denom
  ) public Validator(_validators, _num, _denom) {}

  function addValidators(address[] calldata _validators) external onlyAdmin {
    for (uint256 _i; _i < _validators.length; ++_i) {
      _addValidator(nonce++, _validators[_i]);
    }
  }

  function removeValidator(address _validator) external onlyAdmin {
    _removeValidator(nonce++, _validator);
  }

  function updateQuorum(uint256 _numerator, uint256 _denominator) external onlyAdmin {
    _updateQuorum(nonce++, _numerator, _denominator);
  }
}
