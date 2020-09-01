pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/proxy/ProxyStorage.sol";
import "@axie/contract-library/contracts/lifecycle/Pausable.sol";
import "../common/Validator.sol";
import "../common/Registry.sol";
import "../common/Acknowledgement.sol";


/**
 * @title SidechainGatewayStorage
 * @dev Storage of deposit and withdraw information.
 */
contract SidechainGatewayStorage is ProxyStorage, Pausable {

  event TokenDeposited(
    uint256 indexed depositId,
    address indexed owner,
    address indexed tokenAddress,
    uint256 tokenNumber  // ERC-20 amount or ERC721 tokenId
  );

  event TokenWithdrew(
    uint256 indexed withdrawId,
    address indexed owner,
    address indexed tokenAddress,
    address mainchainAddress,
    uint32  standard,
    uint256 tokenNumber
  );

  event RequestTokenWithdrawalSigAgain(
    uint256 indexed withdrawalId,
    address indexed owner,
    address indexed tokenAddress,
    address mainchainAddress,
    uint32  standard,
    uint256 tokenNumber
  );

  struct DepositEntry {
    address owner;
    address tokenAddress;
    uint256 tokenNumber;
  }

  struct WithdrawalEntry {
    address owner;
    address tokenAddress;
    address mainchainAddress;
    uint32  standard;
    uint256 tokenNumber;
  }

  struct PendingWithdrawalInfo {
    uint256[] withdrawalIds;
    uint256 count;
  }

  Registry public registry;

  // Final deposit state, update only once when there is enough acknowledgement
  mapping(uint256 => DepositEntry) public deposits;

  uint256 public withdrawalCount;
  WithdrawalEntry[] public withdrawals;
  mapping(uint256 => mapping(address => bytes)) public withdrawalSig;
  mapping(uint256 => address[]) public withdrawalSigners;

  // Data for single users
  mapping(address => uint256[]) pendingWithdrawals;
  uint256 public maxPendingWithdrawal;

  function updateRegistry(address _registry) external onlyAdmin {
    registry = Registry(_registry);
  }

  function updateMaxPendingWithdrawal(uint256 _maxPendingWithdrawal) public onlyAdmin {
    maxPendingWithdrawal = _maxPendingWithdrawal;
  }

  function _getValidator() internal view returns (Validator _validator) {
    _validator = Validator(registry.getContract(registry.VALIDATOR()));
  }

  function _getAck() internal view returns (Acknowledgement _ack) {
    _ack = Acknowledgement(registry.getContract(registry.ACKNOWLEDGEMENT()));
  }

  function _getDepositAckChannel() internal view returns (bytes32 _channel) {
    Acknowledgement _ack = _getAck();
    _channel = _ack.getChannel(_ack.DEPOSIT_CHANNEL());
  }

  function _getWithdrawalAckChannel() internal view returns (bytes32 _channel) {
    Acknowledgement _ack = _getAck();
    _channel = _ack.getChannel(_ack.WITHDRAWAL_CHANNEL());
  }
}
