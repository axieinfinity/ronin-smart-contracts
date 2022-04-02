// SPDX-License-Identifier: MIT
pragma solidity ^0.5.17;

import "../../references/HasAdmin.sol";

contract Registry is HasAdmin {
  event ContractAddressUpdated(string indexed _name, bytes32 indexed _code, address indexed _newAddress);

  event TokenMapped(address indexed _mainchainToken, address indexed _sidechainToken, uint32 _standard);

  string public constant GATEWAY = "GATEWAY";
  string public constant WETH_TOKEN = "WETH_TOKEN";
  string public constant VALIDATOR = "VALIDATOR";
  string public constant ACKNOWLEDGEMENT = "ACKNOWLEDGEMENT";

  struct TokenMapping {
    address mainchainToken;
    address sidechainToken;
    uint32 standard; // 20, 721 or any other standards
  }

  mapping(bytes32 => address) public contractAddresses;
  mapping(address => TokenMapping) public mainchainMap;
  mapping(address => TokenMapping) public sidechainMap;

  function getContract(string calldata _name) external view returns (address _address) {
    bytes32 _code = getCode(_name);
    _address = contractAddresses[_code];
    require(_address != address(0));
  }

  function isTokenMapped(
    address _token,
    uint32 _standard,
    bool _isMainchain
  ) external view returns (bool) {
    TokenMapping memory _mapping = _getTokenMapping(_token, _isMainchain);

    return
      _mapping.mainchainToken != address(0) && _mapping.sidechainToken != address(0) && _mapping.standard == _standard;
  }

  function updateContract(string calldata _name, address _newAddress) external onlyAdmin {
    bytes32 _code = getCode(_name);
    contractAddresses[_code] = _newAddress;

    emit ContractAddressUpdated(_name, _code, _newAddress);
  }

  function mapToken(
    address _mainchainToken,
    address _sidechainToken,
    uint32 _standard
  ) external onlyAdmin {
    TokenMapping memory _map = TokenMapping(_mainchainToken, _sidechainToken, _standard);

    mainchainMap[_mainchainToken] = _map;
    sidechainMap[_sidechainToken] = _map;

    emit TokenMapped(_mainchainToken, _sidechainToken, _standard);
  }

  function clearMapToken(address _mainchainToken, address _sidechainToken) external onlyAdmin {
    TokenMapping storage _mainchainMap = mainchainMap[_mainchainToken];
    _clearMapEntry(_mainchainMap);

    TokenMapping storage _sidechainMap = sidechainMap[_sidechainToken];
    _clearMapEntry(_sidechainMap);
  }

  function getMappedToken(address _token, bool _isMainchain)
    external
    view
    returns (
      address _mainchainToken,
      address _sidechainToken,
      uint32 _standard
    )
  {
    TokenMapping memory _mapping = _getTokenMapping(_token, _isMainchain);
    _mainchainToken = _mapping.mainchainToken;
    _sidechainToken = _mapping.sidechainToken;
    _standard = _mapping.standard;
  }

  function getCode(string memory _name) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(_name));
  }

  function _getTokenMapping(address _token, bool isMainchain) internal view returns (TokenMapping memory _mapping) {
    if (isMainchain) {
      _mapping = mainchainMap[_token];
    } else {
      _mapping = sidechainMap[_token];
    }
  }

  function _clearMapEntry(TokenMapping storage _entry) internal {
    _entry.mainchainToken = address(0);
    _entry.sidechainToken = address(0);
    _entry.standard = 0;
  }
}
