// SPDX-License-Identifier: MIT
pragma solidity ^0.5.2;

import "./ProxyStorage.sol";

/**
 * @title Proxy
 * @dev Gives the possibility to delegate any call to a foreign implementation.
 */
contract Proxy is ProxyStorage {
  event ProxyUpdated(address indexed _new, address indexed _old);

  constructor(address _proxyTo) public {
    updateProxyTo(_proxyTo);
  }

  /**
   * @dev Tells the address of the implementation where every call will be delegated.
   * @return address of the implementation to which it will be delegated
   */
  function implementation() public view returns (address) {
    return _proxyTo;
  }

  /**
   * @dev See more at: https://eips.ethereum.org/EIPS/eip-897
   * @return type of proxy - always upgradable
   */
  function proxyType() external pure returns (uint256) {
    // Upgradeable proxy
    return 2;
  }

  /**
   * @dev Fallback function allowing to perform a delegatecall to the given implementation.
   * This function will return whatever the implementation call returns
   */
  function() external payable {
    address _impl = implementation();
    require(_impl != address(0));

    assembly {
      let ptr := mload(0x40)
      calldatacopy(ptr, 0, calldatasize)
      let result := delegatecall(gas, _impl, ptr, calldatasize, 0, 0)
      let size := returndatasize
      returndatacopy(ptr, 0, size)

      switch result
      case 0 {
        revert(ptr, size)
      }
      default {
        return(ptr, size)
      }
    }
  }

  function updateProxyTo(address _newProxyTo) public onlyAdmin {
    require(_newProxyTo != address(0x0));

    _proxyTo = _newProxyTo;
    emit ProxyUpdated(_newProxyTo, _proxyTo);
  }
}
