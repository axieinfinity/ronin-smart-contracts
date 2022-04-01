// SPDX-License-Identifier: MIT
pragma solidity ^0.5.17;

import "../../references/HasAdmin.sol";
import "../../references/Pausable.sol";

contract PausableAdmin is HasAdmin {
  Pausable public gateway;

  constructor(Pausable _gateway) public {
    gateway = _gateway;
  }

  function pauseGateway() external onlyAdmin {
    gateway.pause();
  }

  function unpauseGateway() external onlyAdmin {
    gateway.unpause();
  }
}
