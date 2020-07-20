pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/proxy/Proxy.sol";
import "./SidechainGatewayStorage.sol";
import "../common/IValidator.sol";
import "../common/Registry.sol";

contract SidechainGatewayProxy is Proxy, SidechainGatewayStorage {
  constructor(address _proxyTo, address _registry, address _validator, uint256 _quorum) public Proxy(_proxyTo) {
    registry = Registry(_registry);
    validator = IValidator(_validator);
    quorum = _quorum;
  }
}
