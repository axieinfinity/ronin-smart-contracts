// SPDX-License-Identifier: MIT
pragma solidity ^0.5.17;

import "../../references/ProxyStorage.sol";
import "../../references/Pausable.sol";
import "../common/Validator.sol";
import "../common/Registry.sol";
import "./MainchainValidator.sol";

/**
 * @title GatewayStorage
 * @dev Storage of deposit and withdraw information.
 */
contract MainchainGatewayStorage is ProxyStorage, Pausable {
  event TokenDeposited(
    uint256 indexed _depositId,
    address indexed _owner,
    address indexed _tokenAddress,
    address _sidechainAddress,
    uint32 _standard,
    uint256 _tokenNumber // ERC-20 amount or ERC721 tokenId
  );

  event TokenWithdrew(
    uint256 indexed _withdrawId,
    address indexed _owner,
    address indexed _tokenAddress,
    uint256 _tokenNumber
  );

  struct DepositEntry {
    address owner;
    address tokenAddress;
    address sidechainAddress;
    uint32 standard;
    uint256 tokenNumber;
  }

  struct WithdrawalEntry {
    address owner;
    address tokenAddress;
    uint256 tokenNumber;
  }

  Registry public registry;

  uint256 public depositCount;
  DepositEntry[] public deposits;
  mapping(uint256 => WithdrawalEntry) public withdrawals;

  function updateRegistry(address _registry) external onlyAdmin {
    registry = Registry(_registry);
  }
}
