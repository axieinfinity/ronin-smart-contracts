pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/math/SafeMath.sol";
import "./IValidator.sol";

contract Validator is IValidator {
    using SafeMath for uint256;

    mapping(address => bool) validatorMap;
    address[] public validators;
    uint256 public validatorCount;
    uint256 public num;
    uint256 public denom;

    constructor(address[] memory _validators, uint256 _num, uint256 _denom) public {
        validators = _validators;
        validatorCount = _validators.length;

        address _validator;

        for (uint256 _i = 0; _i < validatorCount; _i++) {
            _validator = _validators[_i];
            validatorMap[_validator] = true;
        }

        num = _num;
        denom = _denom;
    }

    function _addValidator(address _validator) internal {
        require(!validatorMap[_validator]);

        validators.push(_validator);
        validatorMap[_validator] = true;
        validatorCount++;

        emit ValidatorAdded(_validator);

    }

    function _removeValidator(uint256 _index) internal {
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

    function _updateQuorum(uint256 _numerator, uint256 _denominator) internal {
        uint256 _previousNumerator = num;
        uint256 _previousDenominator = denom;

        num = _numerator;
        denom = _denominator;

        emit ThresholdUpdated(_numerator, _denominator, _previousNumerator, _previousDenominator);
    }

    function isValidator(address _addr) public view returns (bool) {
        return validatorMap[_addr];
    }

    function getValidators() public view returns (address[] memory _validators) {
        _validators = validators;
    }

    function checkThreshold(uint256 _voteCount) public view returns (bool) {
        return _voteCount.mul(denom) > num.mul(validatorCount);
    }
}
