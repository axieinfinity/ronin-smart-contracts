pragma solidity ^0.5.2;

import "./HasAdmin.sol";
/**
 * @title ProxyStorage
 * @dev Store the address of logic contact that the proxy should forward to.
 */
contract ProxyStorage is HasAdmin {
  address internal _proxyTo;
}
