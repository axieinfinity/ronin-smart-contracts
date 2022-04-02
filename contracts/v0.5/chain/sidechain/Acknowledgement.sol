// SPDX-License-Identifier: MIT
pragma solidity ^0.5.17;

import "../../references/HasAdmin.sol";
import "../../references/HasOperators.sol";
import "../common/Validator.sol";

contract Acknowledgement is HasOperators {
  // Acknowledge status, once the acknowledgements reach the threshold the 1st
  // time, it can take effect to the system. E.g. confirm a deposit.
  // Acknowledgments after that should not have any effects.
  enum Status {
    NotApproved,
    FirstApproved,
    AlreadyApproved
  }
  // Mapping from channel => boolean
  mapping(bytes32 => bool) public enabledChannels;
  // Mapping from channel => id => validator => data hash
  mapping(bytes32 => mapping(uint256 => mapping(address => bytes32))) public validatorAck;
  // Mapping from channel => id => data hash => ack count
  mapping(bytes32 => mapping(uint256 => mapping(bytes32 => uint256))) public ackCount;
  // Mapping from channel => id => data hash => ack status
  mapping(bytes32 => mapping(uint256 => mapping(bytes32 => Status))) public ackStatus;

  string public constant DEPOSIT_CHANNEL = "DEPOSIT_CHANNEL";
  string public constant WITHDRAWAL_CHANNEL = "WITHDRAWAL_CHANNEL";
  string public constant VALIDATOR_CHANNEL = "VALIDATOR_CHANNEL";

  Validator public validator;

  constructor(address _validator) public {
    addChannel(DEPOSIT_CHANNEL);
    addChannel(WITHDRAWAL_CHANNEL);
    addChannel(VALIDATOR_CHANNEL);
    validator = Validator(_validator);
  }

  function getChannelHash(string memory _name) public view returns (bytes32 _channel) {
    _channel = _getHash(_name);
    _requireValidChannel(_channel);
  }

  function addChannel(string memory _name) public onlyAdmin {
    bytes32 _channel = _getHash(_name);
    enabledChannels[_channel] = true;
  }

  function removeChannel(string memory _name) public onlyAdmin {
    bytes32 _channel = _getHash(_name);
    _requireValidChannel(_channel);
    delete enabledChannels[_channel];
  }

  function updateValidator(address _validator) public onlyAdmin {
    validator = Validator(_validator);
  }

  function acknowledge(
    string memory _channelName,
    uint256 _id,
    bytes32 _hash,
    address _validator
  ) public onlyOperator returns (Status) {
    bytes32 _channel = getChannelHash(_channelName);
    require(
      validatorAck[_channel][_id][_validator] == bytes32(0),
      "Acknowledgement: the validator already acknowledged"
    );

    validatorAck[_channel][_id][_validator] = _hash;
    Status _status = ackStatus[_channel][_id][_hash];
    uint256 _count = ackCount[_channel][_id][_hash];

    if (validator.checkThreshold(_count + 1)) {
      if (_status == Status.NotApproved) {
        ackStatus[_channel][_id][_hash] = Status.FirstApproved;
      } else {
        ackStatus[_channel][_id][_hash] = Status.AlreadyApproved;
      }
    }

    ackCount[_channel][_id][_hash]++;

    return ackStatus[_channel][_id][_hash];
  }

  function hasValidatorAcknowledged(
    string memory _channelName,
    uint256 _id,
    address _validator
  ) public view returns (bool) {
    bytes32 _channel = _getHash(_channelName);
    return validatorAck[_channel][_id][_validator] != bytes32(0);
  }

  function getAcknowledgementStatus(
    string memory _channelName,
    uint256 _id,
    bytes32 _hash
  ) public view returns (Status) {
    bytes32 _channel = _getHash(_channelName);
    return ackStatus[_channel][_id][_hash];
  }

  function _getHash(string memory _name) internal pure returns (bytes32 _hash) {
    _hash = keccak256(abi.encode(_name));
  }

  function _requireValidChannel(bytes32 _channelHash) internal view {
    require(enabledChannels[_channelHash], "Acknowledgement: invalid channel");
  }
}
