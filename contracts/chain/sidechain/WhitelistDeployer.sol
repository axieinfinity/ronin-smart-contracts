pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/access/HasAdmin.sol";


contract WhitelistDeployer is HasAdmin {
  event AddressWhitelisted(address indexed _address, bool indexed _status);
  event WhitelistAllChange(bool indexed _status);

  mapping (address => bool) public whitelisted;
  bool public whitelistAll;

  // solium-disable-next-line no-empty-blocks
  constructor() public {}

  function whitelist(address _address, bool _status) external onlyAdmin {
    whitelisted[_address] = _status;
    emit AddressWhitelisted(_address, _status);
  }

  function whitelistAllAddresses(bool _status) external onlyAdmin {
    whitelistAll = _status;
    emit WhitelistAllChange(_status);
  }

  function isWhitelisted(address _address) external view returns (bool) {
    return whitelistAll || whitelisted[_address];
  }
}
