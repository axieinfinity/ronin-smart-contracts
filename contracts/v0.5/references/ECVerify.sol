// SPDX-License-Identifier: MIT
pragma solidity ^0.5.2;

library ECVerify {
  enum SignatureMode {
    EIP712,
    GETH,
    TREZOR
  }

  function recover(bytes32 _hash, bytes memory _signature) internal pure returns (address _signer) {
    return recover(_hash, _signature, 0);
  }

  // solium-disable-next-line security/no-assign-params
  function recover(
    bytes32 _hash,
    bytes memory _signature,
    uint256 _index
  ) internal pure returns (address _signer) {
    require(_signature.length >= _index + 66);

    SignatureMode _mode = SignatureMode(uint8(_signature[_index]));
    bytes32 _r;
    bytes32 _s;
    uint8 _v;

    // solium-disable-next-line security/no-inline-assembly
    assembly {
      _r := mload(add(_signature, add(_index, 33)))
      _s := mload(add(_signature, add(_index, 65)))
      _v := and(255, mload(add(_signature, add(_index, 66))))
    }

    if (_v < 27) {
      _v += 27;
    }

    require(_v == 27 || _v == 28);

    if (_mode == SignatureMode.GETH) {
      _hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash));
    } else if (_mode == SignatureMode.TREZOR) {
      _hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n\x20", _hash));
    }

    return ecrecover(_hash, _v, _r, _s);
  }

  function ecverify(
    bytes32 _hash,
    bytes memory _signature,
    address _signer
  ) internal pure returns (bool _valid) {
    return _signer == recover(_hash, _signature);
  }
}
