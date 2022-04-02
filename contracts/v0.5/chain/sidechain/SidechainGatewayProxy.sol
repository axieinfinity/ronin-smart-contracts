// SPDX-License-Identifier: MIT
pragma solidity ^0.5.17;

import "../../references/Proxy.sol";
import "../common/Validator.sol";
import "../common/Registry.sol";
import "./SidechainGatewayStorage.sol";

contract SidechainGatewayProxy is Proxy, SidechainGatewayStorage {
  constructor(
    address _proxyTo,
    address _registry,
    uint256 _maxPendingWithdrawal
  ) public Proxy(_proxyTo) {
    registry = Registry(_registry);
    maxPendingWithdrawal = _maxPendingWithdrawal;
  }
}
