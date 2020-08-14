pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/access/HasAdmin.sol";
import "../common/Acknowledgement.sol";
import "../common/Validator.sol";


/**
 * @title Validator
 * @dev Simple validator contract
 */
contract SidechainValidator is Validator {
  // Mapping from hash(validator) => nonce
  mapping(bytes32 => uint256) nonces;
  // Mapping from hash(validator) => bool
  mapping(bytes32 => bool) updatedAck;

  bytes32 ackChannel;

  Registry public registry;
  Acknowledgement acknowledgement;

  modifier onlyValidator() {
    acknowledgement = Acknowledgement(registry.getContract(registry.ACKNOWLEDGEMENT()));
    ackChannel = acknowledgement.getChannel(acknowledgement.VALIDATOR_CHANNEL());
    require(isValidator(msg.sender));
    _;
  }

  constructor(
    address[] memory _validators,
    uint256 _num,
    uint256 _denom
  ) Validator(_validators, _num, _denom) public {
  }

  function addValidator(address _validator) external onlyValidator {
    bytes32 _hash = keccak256(abi.encode(_validator));
    uint256 _nonce = _getNonce(_hash);

    Acknowledgement.Status _status = acknowledgement.acknowledge(ackChannel, _nonce, _hash, msg.sender);
    if (_status == Acknowledgement.Status.FirstApproved) {
      _addValidator(_validator);
      updatedAck[_hash] = true;
    }
  }

  function removeValidator(uint256 _index) external onlyValidator {
    require(_index < validatorCount);

    bytes32 _hash = keccak256(abi.encode(_index));
    uint256 _nonce = _getNonce(_hash);

    Acknowledgement.Status _status = acknowledgement.acknowledge(ackChannel, _nonce, _hash, msg.sender);
    if (_status == Acknowledgement.Status.FirstApproved) {
      _removeValidator(_index);
      updatedAck[_hash] = true;
    }
  }

  function updateQuorum(uint256 _numerator, uint256 _denominator) external onlyValidator {
    bytes32 _hash = keccak256(abi.encode(_numerator, _denominator));
    uint256 _nonce = _getNonce(_hash);

    Acknowledgement.Status _status = acknowledgement.acknowledge(ackChannel, _nonce, _hash, msg.sender);
    if (_status == Acknowledgement.Status.FirstApproved) {
      _updateQuorum(_numerator, _denominator);
      updatedAck[_hash] = true;
    }
  }

  function _getNonce(bytes32 _hash) internal returns (uint256 _nonce) {
    if (updatedAck[_hash]) {
      _nonce = ++nonces[_hash];
      delete updatedAck[_hash];
    } else {
      _nonce = nonces[_hash];
    }
  }
}
