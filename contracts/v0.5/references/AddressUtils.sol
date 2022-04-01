// SPDX-License-Identifier: MIT
pragma solidity ^0.5.2;

library AddressUtils {
  function toPayable(address _address) internal pure returns (address payable _payable) {
    return address(uint160(_address));
  }

  function isContract(address _address) internal view returns (bool _correct) {
    uint256 _size;
    // solium-disable-next-line security/no-inline-assembly
    assembly {
      _size := extcodesize(_address)
    }
    return _size > 0;
  }
}
