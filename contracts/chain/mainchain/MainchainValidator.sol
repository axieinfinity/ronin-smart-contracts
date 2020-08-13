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
  ) public Validator(_validators, _num, _denom) {
  }

  function addValidator(address _validator) external onlyAdmin {
    _addValidator(_validator);
  }

  function removeValidator(uint256 _index) external onlyAdmin {
    _removeValidator(_index);
  }

  function updateQuorum(uint256 _numerator, uint256 _denominator) external onlyAdmin {
    _updateQuorum(_numerator, _denominator);
  }
}
