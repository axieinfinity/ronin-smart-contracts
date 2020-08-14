pragma solidity ^0.5.2;


contract IValidator {
  event ValidatorAdded(address indexed validator);
  event ValidatorRemoved(address indexed validator);
  event ThresholdUpdated(
    uint256 indexed numerator,
    uint256 indexed denominator,
    uint256 previousNumerator,
    uint256 previousDenominator
  );

  function isValidator(address _addr) public view returns (bool);

  function getValidators() public view returns (address[] memory _validators);

  function checkThreshold(uint256 _voteCount) public view returns (bool);
}
