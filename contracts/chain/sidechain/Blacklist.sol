pragma solidity ^0.5.17;

import "@axie/contract-library/contracts/access/HasAdmin.sol";


contract Blacklist is HasAdmin {
  event AddressBlacklisted(address indexed _address, bool indexed _status);
  event BlacklistAllChange(bool indexed _status);

  mapping (address => bool) internal _blacklisted;

  bool public blacklistAll;

  constructor()
    public
  {}

  function blacklist(address _address, bool _status)
    external
    onlyAdmin
  {
    _blacklisted[_address] = _status;
    emit AddressBlacklisted(_address, _status);
  }

  function blacklistAllAddresses(bool _status)
    external
    onlyAdmin
  {
    blacklistAll = _status;
    emit BlacklistAllChange(_status);
  }

  function blacklisted(address _address)
    external
    view
    returns (bool)
  {
    return blacklistAll || _blacklisted[_address];
  }
}
