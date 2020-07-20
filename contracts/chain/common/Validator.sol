pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/access/HasAdmin.sol";
import "./IValidator.sol";

/**
 * @title Validator
 * @dev Simple validator contract
 */
contract Validator is IValidator, HasAdmin {
  address[] public validators;
  uint256 public validatorCount;
  mapping (address => bool) validatorMap;

  constructor() public {}

  function addValidators(address[] calldata _validators) external onlyAdmin {
    address _validator;

    for (uint256 i = 0; i < _validators.length; i++) {
      _validator = _validators[i];

      if (!validatorMap[_validator]) {
        validators.push(_validator);
        validatorMap[_validator] = true;
        emit ValidatorAdded(_validator);
      }
    }
  }

  function removeValidator(uint256 _index) external onlyAdmin {
    require(_index < validatorCount);

    address _validator = validators[_index];
    validatorMap[_validator] = false;
    for (uint256 _i = _index; _i + 1 < validatorCount; _i++) {
      validators[_i] = validators[_i + 1];
    }

    validatorCount--;
    validators.length--;

    emit ValidatorRemoved(_validator);
  }

  function isValidator(address _addr) public view returns (bool _result) {
    _result = validatorMap[_addr];
  }

  function getValidators() public view returns(address[] memory _validators) {
    _validators = validators;
  }
}
