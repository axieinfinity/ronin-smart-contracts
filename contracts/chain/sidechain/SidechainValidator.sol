pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/access/HasAdmin.sol";
import "../common/Acknowledgement.sol";
import "../common/Validator.sol";


/**
 * @title Validator
 * @dev Simple validator contract
 */
contract SidechainValidator is Validator {
  Registry public registry;

  modifier onlyValidator() {
    require(isValidator(msg.sender));
    _;
  }

  constructor(
    address[] memory _validators,
    uint256 _num,
    uint256 _denom
  ) Validator(_validators, _num, _denom) public {
  }

  function addValidator(uint256 _id, address _validator) external onlyValidator {
    bytes32 _hash = keccak256(abi.encode("addValidator", _validator));

    Acknowledgement.Status _status = _getAck().acknowledge(_getAckChannel(), _id, _hash, msg.sender);
    if (_status == Acknowledgement.Status.FirstApproved) {
      _addValidator(_id, _validator);
    }
  }

  function removeValidator(uint256 _id, address _validator) external onlyValidator {
    require(isValidator(_validator));

    bytes32 _hash = keccak256(abi.encode("removeValidator", _validator));

    Acknowledgement.Status _status = _getAck().acknowledge(_getAckChannel(), _id, _hash, msg.sender);
    if (_status == Acknowledgement.Status.FirstApproved) {
      _removeValidator(_id, _validator);
    }
  }

  function updateQuorum(uint256 _id, uint256 _numerator, uint256 _denominator) external onlyValidator {
    bytes32 _hash = keccak256(abi.encode("updateQuorum", _numerator, _denominator));

    Acknowledgement.Status _status = _getAck().acknowledge(_getAckChannel(), _id, _hash, msg.sender);
    if (_status == Acknowledgement.Status.FirstApproved) {
      _updateQuorum(_id, _numerator, _denominator);
    }
  }

  function _getAck() internal view returns (Acknowledgement _ack) {
    _ack = Acknowledgement(registry.getContract(registry.ACKNOWLEDGEMENT()));
  }

  function _getAckChannel() internal view returns (bytes32 _ackChannel) {
    Acknowledgement _ack = _getAck();
    _ackChannel = _ack.getChannel(_ack.VALIDATOR_CHANNEL());
  }
}
