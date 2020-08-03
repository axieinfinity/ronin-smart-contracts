pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/proxy/ProxyStorage.sol";
import "@axie/contract-library/contracts/lifecycle/Pausable.sol";
import "../common/IValidator.sol";
import "../common/Registry.sol";


/**
 * @title GatewayStorage
 * @dev Storage of deposit and withdraw information.
 */
contract MainchainGatewayStorage is ProxyStorage, Pausable {

  event TokenDeposited(
    uint256 indexed depositId,
    address indexed owner,
    address indexed tokenAddress,
    address sidechainAddress,
    uint32  standard,
    uint256 tokenNumber // ERC-20 amount or ERC721 tokenId
  );

  event TokenWithdrew(
    uint256 indexed withdrawId,
    address indexed owner,
    address indexed tokenAddres,
    uint256 tokenNumber
  );

  struct DepositEntry {
    address owner;
    address tokenAddress;
    address sidechainAddress;
    uint32  standard;
    uint256 tokenNumber;
  }

  struct WithdrawalEntry {
    address owner;
    address tokenAddress;
    uint256 tokenNumber;
  }

  Registry public registry;
  IValidator public validator;
  uint256 public withdrawalQuorum;

  uint256 public depositCount;
  DepositEntry[] public deposits;
  mapping(uint256 => WithdrawalEntry) public withdrawals;

  function updateRegistry(address _registry) external onlyAdmin {
    registry = Registry(_registry);
  }

  function updateValidator(address _validator) external onlyAdmin {
    validator = IValidator(_validator);
  }

  function updateQuorum(uint256 _quorum) external onlyAdmin {
    withdrawalQuorum = _quorum;
  }
}
