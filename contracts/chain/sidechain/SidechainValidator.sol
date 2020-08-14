pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/access/HasAdmin.sol";
import "../common/Acknowledgement.sol";
import "../common/Validator.sol";


/**
 * @title Validator
 * @dev Simple validator contract
 */
contract SidechainValidator is Validator {
  // Mapping from hash => nonce
  mapping(bytes32 => uint256) nonces;
  // Mapping from hash => bool
  mapping(bytes32 => bool) updatedAck;

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

  function addValidator(address _validator) external onlyValidator {
    bytes32 _hash = keccak256(abi.encode("addValidator", _validator));
    uint256 _nonce = _getNonce(_hash);

    Acknowledgement.Status _status = _getAck().acknowledge(_getAckChannel(), _nonce, _hash, msg.sender);
    if (_status == Acknowledgement.Status.FirstApproved) {
      _addValidator(_validator);
      updatedAck[_hash] = true;
    }
  }

  function removeValidator(uint256 _index) external onlyValidator {
    require(_index < validatorCount);

    bytes32 _hash = keccak256(abi.encode("removeValidator", _index));
    uint256 _nonce = _getNonce(_hash);

    Acknowledgement.Status _status = _getAck().acknowledge(_getAckChannel(), _nonce, _hash, msg.sender);
    if (_status == Acknowledgement.Status.FirstApproved) {
      _removeValidator(_index);
      updatedAck[_hash] = true;
    }
  }

  function updateQuorum(uint256 _numerator, uint256 _denominator) external onlyValidator {
    bytes32 _hash = keccak256(abi.encode("updateQuorum", _numerator, _denominator));
    uint256 _nonce = _getNonce(_hash);

    Acknowledgement.Status _status = _getAck().acknowledge(_getAckChannel(), _nonce, _hash, msg.sender);
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

  function _getAck() internal view returns (Acknowledgement _ack) {
    _ack = Acknowledgement(registry.getContract(registry.ACKNOWLEDGEMENT()));
  }

  function _getAckChannel() internal view returns (bytes32 _ackChannel) {
    Acknowledgement _ack = _getAck();
    _ackChannel = _ack.getChannel(_ack.VALIDATOR_CHANNEL());
  }
}
