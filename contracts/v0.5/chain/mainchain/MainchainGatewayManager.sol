// SPDX-License-Identifier: MIT
pragma solidity ^0.5.17;

import "../../references/ERC20/IERC20.sol";
import "../../references/ERC20/IERC20Mintable.sol";
import "../../references/ERC721/IERC721.sol";
import "../../references/ERC721/IERC721Mintable.sol";
import "../../references/ECVerify.sol";
import "../../references/SafeMath.sol";
import "../../references/AddressUtils.sol";
import "./WETH.sol";
import "./MainchainGatewayStorage.sol";

/**
 * @title MainchainGatewayManager
 * @dev Logic to handle deposits and withdrawl on Mainchain.
 */
contract MainchainGatewayManager is MainchainGatewayStorage {
  using AddressUtils for address;
  using SafeMath for uint256;
  using ECVerify for bytes32;

  modifier onlyMappedToken(address _token, uint32 _standard) {
    require(registry.isTokenMapped(_token, _standard, true), "MainchainGatewayManager: Token is not mapped");
    _;
  }

  modifier onlyNewWithdrawal(uint256 _withdrawalId) {
    WithdrawalEntry storage _entry = withdrawals[_withdrawalId];
    require(_entry.owner == address(0) && _entry.tokenAddress == address(0));
    _;
  }

  // Should be able to withdraw from WETH
  function() external payable {}

  function depositEth() external payable whenNotPaused returns (uint256) {
    return depositEthFor(msg.sender);
  }

  function depositERC20(address _token, uint256 _amount) external whenNotPaused returns (uint256) {
    return depositERC20For(msg.sender, _token, _amount);
  }

  function depositERC721(address _token, uint256 _tokenId) external whenNotPaused returns (uint256) {
    return depositERC721For(msg.sender, _token, _tokenId);
  }

  function depositEthFor(address _owner) public payable whenNotPaused returns (uint256) {
    address _weth = registry.getContract(registry.WETH_TOKEN());
    WETH(_weth).deposit.value(msg.value)();
    return _createDepositEntry(_owner, _weth, 20, msg.value);
  }

  function depositERC20For(
    address _user,
    address _token,
    uint256 _amount
  ) public whenNotPaused returns (uint256) {
    require(
      IERC20(_token).transferFrom(msg.sender, address(this), _amount),
      "MainchainGatewayManager: ERC-20 token transfer failed"
    );
    return _createDepositEntry(_user, _token, 20, _amount);
  }

  function depositERC721For(
    address _user,
    address _token,
    uint256 _tokenId
  ) public whenNotPaused returns (uint256) {
    IERC721(_token).transferFrom(msg.sender, address(this), _tokenId);
    return _createDepositEntry(_user, _token, 721, _tokenId);
  }

  function depositBulkFor(
    address _user,
    address[] memory _tokens,
    uint256[] memory _tokenNumbers
  ) public whenNotPaused {
    require(_tokens.length == _tokenNumbers.length);

    for (uint256 _i = 0; _i < _tokens.length; _i++) {
      address _token = _tokens[_i];
      uint256 _tokenNumber = _tokenNumbers[_i];
      (, , uint32 _standard) = registry.getMappedToken(_token, true);

      if (_standard == 20) {
        depositERC20For(_user, _token, _tokenNumber);
      } else if (_standard == 721) {
        depositERC721For(_user, _token, _tokenNumber);
      } else {
        revert("Token is not mapped or token type not supported");
      }
    }
  }

  function withdrawToken(
    uint256 _withdrawalId,
    address _token,
    uint256 _amount,
    bytes memory _signatures
  ) public whenNotPaused {
    withdrawTokenFor(_withdrawalId, msg.sender, _token, _amount, _signatures);
  }

  function withdrawTokenFor(
    uint256 _withdrawalId,
    address _user,
    address _token,
    uint256 _amount,
    bytes memory _signatures
  ) public whenNotPaused {
    (, , uint32 _tokenType) = registry.getMappedToken(_token, true);

    if (_tokenType == 20) {
      withdrawERC20For(_withdrawalId, _user, _token, _amount, _signatures);
    } else if (_tokenType == 721) {
      withdrawERC721For(_withdrawalId, _user, _token, _amount, _signatures);
    }
  }

  function withdrawERC20(
    uint256 _withdrawalId,
    address _token,
    uint256 _amount,
    bytes memory _signatures
  ) public whenNotPaused {
    withdrawERC20For(_withdrawalId, msg.sender, _token, _amount, _signatures);
  }

  function withdrawERC20For(
    uint256 _withdrawalId,
    address _user,
    address _token,
    uint256 _amount,
    bytes memory _signatures
  ) public whenNotPaused onlyMappedToken(_token, 20) {
    bytes32 _hash = keccak256(abi.encodePacked("withdrawERC20", _withdrawalId, _user, _token, _amount));

    require(verifySignatures(_hash, _signatures));

    if (_token == registry.getContract(registry.WETH_TOKEN())) {
      _withdrawETHFor(_user, _amount);
    } else {
      uint256 _gatewayBalance = IERC20(_token).balanceOf(address(this));

      if (_gatewayBalance < _amount) {
        require(
          IERC20Mintable(_token).mint(address(this), _amount.sub(_gatewayBalance)),
          "MainchainGatewayManager: Minting ERC20 token to gateway failed"
        );
      }

      require(IERC20(_token).transfer(_user, _amount), "Transfer failed");
    }

    _insertWithdrawalEntry(_withdrawalId, _user, _token, _amount);
  }

  function withdrawERC721(
    uint256 _withdrawalId,
    address _token,
    uint256 _tokenId,
    bytes memory _signatures
  ) public whenNotPaused {
    withdrawERC721For(_withdrawalId, msg.sender, _token, _tokenId, _signatures);
  }

  function withdrawERC721For(
    uint256 _withdrawalId,
    address _user,
    address _token,
    uint256 _tokenId,
    bytes memory _signatures
  ) public whenNotPaused onlyMappedToken(_token, 721) {
    bytes32 _hash = keccak256(abi.encodePacked("withdrawERC721", _withdrawalId, _user, _token, _tokenId));

    require(verifySignatures(_hash, _signatures));

    if (!_tryERC721TransferFrom(_token, address(this), _user, _tokenId)) {
      require(
        IERC721Mintable(_token).mint(_user, _tokenId),
        "MainchainGatewayManager: Minting ERC721 token to gateway failed"
      );
    }

    _insertWithdrawalEntry(_withdrawalId, _user, _token, _tokenId);
  }

  /**
   * @dev returns true if there is enough signatures from validators.
   */
  function verifySignatures(bytes32 _hash, bytes memory _signatures) public view returns (bool) {
    uint256 _signatureCount = _signatures.length.div(66);

    Validator _validator = Validator(registry.getContract(registry.VALIDATOR()));
    uint256 _validatorCount = 0;
    address _lastSigner = address(0);

    for (uint256 i = 0; i < _signatureCount; i++) {
      address _signer = _hash.recover(_signatures, i.mul(66));
      if (_validator.isValidator(_signer)) {
        _validatorCount++;
      }
      // Prevent duplication of signatures
      require(_signer > _lastSigner);
      _lastSigner = _signer;
    }

    return _validator.checkThreshold(_validatorCount);
  }

  function _createDepositEntry(
    address _owner,
    address _token,
    uint32 _standard,
    uint256 _number
  ) internal onlyMappedToken(_token, _standard) returns (uint256 _depositId) {
    (, address _sidechainToken, uint32 _tokenStandard) = registry.getMappedToken(_token, true);
    require(_standard == _tokenStandard);

    DepositEntry memory _entry = DepositEntry(_owner, _token, _sidechainToken, _standard, _number);

    deposits.push(_entry);
    _depositId = depositCount++;

    emit TokenDeposited(_depositId, _owner, _token, _sidechainToken, _standard, _number);
  }

  function _insertWithdrawalEntry(
    uint256 _withdrawalId,
    address _owner,
    address _token,
    uint256 _number
  ) internal onlyNewWithdrawal(_withdrawalId) {
    WithdrawalEntry memory _entry = WithdrawalEntry(_owner, _token, _number);

    withdrawals[_withdrawalId] = _entry;

    emit TokenWithdrew(_withdrawalId, _owner, _token, _number);
  }

  function _withdrawETHFor(address _user, uint256 _amount) internal {
    address _weth = registry.getContract(registry.WETH_TOKEN());
    WETH(_weth).withdraw(_amount);
    _user.toPayable().transfer(_amount);
  }

  // See more here https://blog.polymath.network/try-catch-in-solidity-handling-the-revert-exception-f53718f76047
  function _tryERC721TransferFrom(
    address _token,
    address _from,
    address _to,
    uint256 _tokenId
  ) internal returns (bool) {
    (bool success, ) = _token.call(abi.encodeWithSelector(IERC721(_token).transferFrom.selector, _from, _to, _tokenId));
    return success;
  }
}
