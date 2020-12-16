pragma solidity ^0.5.17;

import "@axie/contract-library/contracts/proxy/Proxy.sol";
import "./MainchainGatewayStorage.sol";
import "../common/Validator.sol";
import "../common/Registry.sol";


contract MainchainGatewayProxy is Proxy, MainchainGatewayStorage {
  constructor(address _proxyTo, address _registry)
    public
    Proxy(_proxyTo)
  {
    registry = Registry(_registry);
  }
}
