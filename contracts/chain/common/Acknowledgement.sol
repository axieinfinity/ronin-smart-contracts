pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/math/SafeMath.sol";
import "@axie/contract-library/contracts/access/HasAdmin.sol";
import "./Registry.sol";
import "./Validator.sol";

contract Acknowledgement is HasAdmin {
    // Acknowledge status
    enum Status {NotApproved, FirstApproved, AlreadyApproved}
    // Mapping from channel => boolean
    mapping(bytes32 => bool) channels;
    // Mapping from channel => nonce => validator => hash entry
    mapping(bytes32 => mapping(uint256 => mapping(address => bytes32))) validatorAck;
    // Mapping from channel => nonce => hash => ack count
    mapping(bytes32 => mapping(uint256 => mapping(bytes32 => uint256))) ackCount;
    // Mapping from channel => nonce => hash => ack status
    mapping(bytes32 => mapping(uint256 => mapping(bytes32 => uint8))) ackStatus;

    string public constant DEPOSIT_CHANNEL = "DEPOSIT_CHANNEL";
    string public constant WITHDRAWAL_CHANNEL = "WITHDRAWAL_CHANNEL";
    string public constant VALIDATOR_CHANNEL = "VALIDATOR_CHANNEL";

    Registry public registry;
    Validator validator;

    modifier validChannel(bytes32 _hash) {
        require(channels[_hash], "invalid channel");
        _;
    }

    modifier onlyValidator() {
        validator = Validator(registry.getContract(registry.VALIDATOR()));
        require(validator.isValidator(msg.sender), "sender is not a validator");
        _;
    }

    constructor (address _registry) public {
        addChannel(DEPOSIT_CHANNEL);
        addChannel(WITHDRAWAL_CHANNEL);
        addChannel(VALIDATOR_CHANNEL);
        registry = Registry(_registry);
    }

    function _getHash(string memory _name) internal pure returns (bytes32 _hash) {
        _hash = keccak256(abi.encode(_name));
    }

    function getChannel(string memory _name) public view validChannel(_getHash(_name)) returns (bytes32 _channel) {
        _channel = _getHash(_name);
    }

    function addChannel(string memory _name) public onlyAdmin {
        channels[_getHash(_name)] = true;
    }

    function removeChannel(string memory _name) public onlyAdmin validChannel(_getHash(_name)) {
        delete channels[_getHash(_name)];
    }

    function updateRegistry(address _registry) external onlyAdmin {
        registry = Registry(_registry);
    }

    function acknowledge(bytes32 _channel, uint256 _nonce, bytes32 _hash) public onlyValidator validChannel(_channel) returns (Status) {
        require(validatorAck[_channel][_nonce][msg.sender] == bytes32(0), "the validator already acknowledged");

        validatorAck[_channel][_nonce][msg.sender] = _hash;
        uint8 _status = ackStatus[_channel][_nonce][_hash];
        uint256 _count = ackCount[_channel][_nonce][_hash];

        if (validator.checkThreshold(_count + 1)) {
            if (_status == uint8(Status.NotApproved)) {
                ackStatus[_channel][_nonce][_hash] = uint8(Status.FirstApproved);
            } else {
                ackStatus[_channel][_nonce][_hash] = uint8(Status.AlreadyApproved);
            }
        }

        ackCount[_channel][_nonce][_hash]++;

        return Status(ackStatus[_channel][_nonce][_hash]);
    }
}
