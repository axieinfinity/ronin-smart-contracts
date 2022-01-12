pragma solidity ^0.5.17;

import "@axie/contract-library/contracts/access/HasAdmin.sol";


contract Blacklist is HasAdmin {
  event ContractDisabled(bool indexed _status);

  event AddressesBlacklisted(
    address[] _addresses,
    bool indexed _status
  );

  mapping (address => bool) internal _blacklisted;

  // Returns whether the contract is still valid or not
  bool public disabled;

  constructor()
    public
  {}

  function blacklists(address[] calldata  _addresses, bool _status)
    external
    onlyAdmin
  {
    for (uint256 _i; _i < _addresses.length; _i++) {
      _blacklisted[_addresses[_i]] = _status;
    }
    emit AddressesBlacklisted(_addresses, _status);
  }

  function setDisabled(bool _status)
    external
    onlyAdmin
  {
    disabled = _status;
    emit ContractDisabled(_status);
  }

  function blacklisted(address _address)
    external
    view
    returns (bool)
  {
    return !disabled && _blacklisted[_address];
  }
}
