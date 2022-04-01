// SPDX-License-Identifier: MIT
pragma solidity ^0.5.17;

contract IValidator {
  event ValidatorAdded(uint256 indexed _id, address indexed _validator);
  event ValidatorRemoved(uint256 indexed _id, address indexed _validator);
  event ThresholdUpdated(
    uint256 indexed _id,
    uint256 indexed _numerator,
    uint256 indexed _denominator,
    uint256 _previousNumerator,
    uint256 _previousDenominator
  );

  function isValidator(address _addr) public view returns (bool);

  function getValidators() public view returns (address[] memory _validators);

  function checkThreshold(uint256 _voteCount) public view returns (bool);
}
