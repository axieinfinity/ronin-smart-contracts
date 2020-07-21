pragma solidity ^0.5.2;

contract IValidator {
  event ValidatorAdded(address indexed validator);
  event ValidatorRemoved(address indexed validator);

  function isValidator(address _addr) public view returns (bool _result);
  function getValidators() public view returns (address[] memory _validators);
}
