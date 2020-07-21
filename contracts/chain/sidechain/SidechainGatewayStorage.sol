pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/proxy/ProxyStorage.sol";
import "../common/IValidator.sol";
import "../common/Registry.sol";

/**
 * @title SidechainGatewayStorage
 * @dev Storage of deposit and withdraw information.
 */
contract SidechainGatewayStorage is ProxyStorage {

  event TokenDeposited(
    uint256 indexed depositId,
    address indexed owner,
    address indexed tokenAddress,
    uint256 tokenNumber  // ERC-20 amount or ERC721 tokenId
  );

  event TokenWithdrew(
    uint256 indexed withdrawId,
    address indexed owner,
    address indexed tokenAddres,
    address mainchainAddress,
    uint32  standard,
    uint256 tokenNumber
  );

  event RequestTokenWithdrawalSigAgain(
    uint256 indexed withdrawalId,
    address indexed owner,
    address indexed tokenAddres,
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
    uint256 acknowledgedCount;
  }

  struct PendingWithdrawalInfo {
    uint256[] withdrawalIds;
    uint256 count;
  }

  Registry public registry;
  IValidator public validator;
  uint256 public quorum;

  /**
   * To confirm a deposit, we need >= quorum validators acknowledge the info. However a faulty validator can submit
   * an incorrect entry before the normal one does, so we need to keep track of the submission and choose the majority.
   * We hash the deposit entry and count them.
   */
  // Mapping from depositId => validator => hash of deposit entry
  mapping(uint256 => mapping(address => bytes32)) validatorAck;
  // Mapping from depositId => hash => ack acount
  mapping(uint256 => mapping(bytes32 => uint256)) depositActCount;
  // Mapping from depositId => hash => entry
  mapping(uint256 => mapping(bytes32 => DepositEntry)) depositEntryMap;

  // Final deposit state, update only once when there is enough acknowledgement
  mapping(uint256 => DepositEntry) public deposits;

  uint256 public withdrawalCount;
  WithdrawalEntry[] public withdrawals;
  mapping(uint256 => mapping(address => bytes)) public withdrawalSig;
  mapping(uint256 => address[]) public withdrawalSigners;

  // Data for single users
  mapping(address => uint256[]) pendingWithdrawals;
  mapping(uint256 => mapping(address => bool)) withdrawalValidatorAck;

  function updateRegistry(address _registry) external onlyAdmin {
    registry = Registry(_registry);
  }

  function updateValidator(address _validator) external onlyAdmin {
    validator = IValidator(_validator);
  }

  function updateQuorum(uint256 _quorum) external onlyAdmin {
    quorum = _quorum;
  }
}
