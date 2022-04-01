// SPDX-License-Identifier: MIT
pragma solidity ^0.5.17;

import "../../references/Proxy.sol";
import "../common/Validator.sol";
import "../common/Registry.sol";
import "./MainchainGatewayStorage.sol";

contract MainchainGatewayProxy is Proxy, MainchainGatewayStorage {
  constructor(address _proxyTo, address _registry) public Proxy(_proxyTo) {
    registry = Registry(_registry);
  }
}
