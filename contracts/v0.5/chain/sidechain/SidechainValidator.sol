// SPDX-License-Identifier: MIT
pragma solidity ^0.5.17;

import "../common/Validator.sol";
import "./Acknowledgement.sol";

/**
 * @title Validator
 * @dev Simple validator contract
 */
contract SidechainValidator is Validator {
  Acknowledgement public acknowledgement;

  modifier onlyValidator() {
    require(isValidator(msg.sender));
    _;
  }

  constructor(
    address _acknowledgement,
    address[] memory _validators,
    uint256 _num,
    uint256 _denom
  ) public Validator(_validators, _num, _denom) {
    acknowledgement = Acknowledgement(_acknowledgement);
  }

  function addValidator(uint256 _id, address _validator) external onlyValidator {
    bytes32 _hash = keccak256(abi.encode("addValidator", _validator));

    Acknowledgement.Status _status = acknowledgement.acknowledge(_getAckChannel(), _id, _hash, msg.sender);
    if (_status == Acknowledgement.Status.FirstApproved) {
      _addValidator(_id, _validator);
    }
  }

  function removeValidator(uint256 _id, address _validator) external onlyValidator {
    require(isValidator(_validator));

    bytes32 _hash = keccak256(abi.encode("removeValidator", _validator));

    Acknowledgement.Status _status = acknowledgement.acknowledge(_getAckChannel(), _id, _hash, msg.sender);
    if (_status == Acknowledgement.Status.FirstApproved) {
      _removeValidator(_id, _validator);
    }
  }

  function updateQuorum(
    uint256 _id,
    uint256 _numerator,
    uint256 _denominator
  ) external onlyValidator {
    bytes32 _hash = keccak256(abi.encode("updateQuorum", _numerator, _denominator));

    Acknowledgement.Status _status = acknowledgement.acknowledge(_getAckChannel(), _id, _hash, msg.sender);
    if (_status == Acknowledgement.Status.FirstApproved) {
      _updateQuorum(_id, _numerator, _denominator);
    }
  }

  function _getAckChannel() internal view returns (string memory) {
    return acknowledgement.VALIDATOR_CHANNEL();
  }
}
