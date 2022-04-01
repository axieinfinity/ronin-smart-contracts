// SPDX-License-Identifier: MIT
pragma solidity ^0.5.17;
pragma experimental ABIEncoderV2;

import "../../references/ECVerify.sol";
import "../../references/SafeMath.sol";
import "../../references/ERC20/IERC20.sol";
import "../../references/ERC20/IERC20Mintable.sol";
import "../../references/ERC721/IERC721.sol";
import "../../references/ERC721/IERC721Mintable.sol";
import "../../references/AddressUtils.sol";
import "./SidechainGatewayStorage.sol";

/**
 * @title SidechainGatewayManager
 * @dev Logic to handle deposits and withdrawals on Sidechain.
 */
contract SidechainGatewayManager is SidechainGatewayStorage {
  using AddressUtils for address;
  using SafeMath for uint256;
  using ECVerify for bytes32;

  modifier onlyMappedToken(address _token, uint32 _standard) {
    require(registry.isTokenMapped(_token, _standard, false), "SidechainGatewayManager: token is not mapped");
    _;
  }

  modifier onlyValidator() {
    require(_getValidator().isValidator(msg.sender), "SidechainGatewayManager: sender is not validator");
    _;
  }

  function() external {
    revert("SidechainGatewayManager: Invalid method");
  }

  function batchDepositERCTokenFor(
    uint256[] calldata _depositIds,
    address[] calldata _owners,
    address[] calldata _tokens,
    uint32[] calldata _standards,
    uint256[] calldata _tokenNumbers
  ) external whenNotPaused onlyValidator {
    require(
      _depositIds.length == _owners.length &&
        _depositIds.length == _tokens.length &&
        _depositIds.length == _standards.length &&
        _depositIds.length == _tokenNumbers.length,
      "SidechainGatewayManager: invalid input array length"
    );

    for (uint256 _i; _i < _depositIds.length; _i++) {
      depositERCTokenFor(_depositIds[_i], _owners[_i], _tokens[_i], _standards[_i], _tokenNumbers[_i]);
    }
  }

  function batchAcknowledWithdrawalOnMainchain(uint256[] calldata _withdrawalIds) external whenNotPaused onlyValidator {
    for (uint256 _i; _i < _withdrawalIds.length; _i++) {
      acknowledWithdrawalOnMainchain(_withdrawalIds[_i]);
    }
  }

  function batchSubmitWithdrawalSignatures(
    uint256[] calldata _withdrawalIds,
    bool[] calldata _shouldReplaces,
    bytes[] calldata _sigs
  ) external whenNotPaused onlyValidator {
    require(
      _withdrawalIds.length == _shouldReplaces.length && _withdrawalIds.length == _sigs.length,
      "SidechainGatewayManager: invalid input array length"
    );

    for (uint256 _i; _i < _withdrawalIds.length; _i++) {
      submitWithdrawalSignatures(_withdrawalIds[_i], _shouldReplaces[_i], _sigs[_i]);
    }
  }

  function withdrawETH(uint256 _amount) external whenNotPaused returns (uint256) {
    address _weth = registry.getContract(registry.WETH_TOKEN());
    return withdrawERC20For(msg.sender, _weth, _amount);
  }

  function withdrawERC20(address _token, uint256 _amount) external whenNotPaused returns (uint256) {
    return withdrawERC20For(msg.sender, _token, _amount);
  }

  function depositERCTokenFor(
    uint256 _depositId,
    address _owner,
    address _token,
    uint32 _standard,
    uint256 _tokenNumber
  ) public whenNotPaused onlyValidator {
    (, , uint32 _tokenStandard) = registry.getMappedToken(_token, false);

    require(_tokenStandard == _standard, "SidechainGatewayManager: token standard is not matched");

    bytes32 _hash = keccak256(abi.encode(_owner, _token, _standard, _tokenNumber));

    Acknowledgement.Status _status = _getAcknowledgementContract().acknowledge(
      _getDepositAckChannel(),
      _depositId,
      _hash,
      msg.sender
    );

    if (_status == Acknowledgement.Status.FirstApproved) {
      if (_standard == 20) {
        _depositERC20For(_owner, _token, _tokenNumber);
      } else if (_standard == 721) {
        _depositERC721For(_owner, _token, _tokenNumber);
      }

      deposits[_depositId] = DepositEntry(_owner, _token, _tokenNumber);
      emit TokenDeposited(_depositId, _owner, _token, _tokenNumber);
    }
  }

  function withdrawERC20For(
    address _owner,
    address _token,
    uint256 _amount
  ) public whenNotPaused returns (uint256) {
    require(
      IERC20(_token).transferFrom(msg.sender, address(this), _amount),
      "SidechainGatewayManager: ERC20 token transfer failed"
    );
    return _createWithdrawalEntry(_owner, _token, 20, _amount);
  }

  function withdrawERC721(address _token, uint256 _tokenId) public whenNotPaused returns (uint256) {
    return withdrawalERC721For(msg.sender, _token, _tokenId);
  }

  function withdrawalERC721For(
    address _owner,
    address _token,
    uint256 _tokenId
  ) public whenNotPaused returns (uint256) {
    IERC721(_token).transferFrom(msg.sender, address(this), _tokenId);
    return _createWithdrawalEntry(_owner, _token, 721, _tokenId);
  }

  function submitWithdrawalSignatures(
    uint256 _withdrawalId,
    bool _shouldReplace,
    bytes memory _sig
  ) public whenNotPaused onlyValidator {
    bytes memory _currentSig = withdrawalSig[_withdrawalId][msg.sender];

    bool _alreadyHasSig = _currentSig.length != 0;

    if (!_shouldReplace && _alreadyHasSig) {
      return;
    }

    withdrawalSig[_withdrawalId][msg.sender] = _sig;
    if (!_alreadyHasSig) {
      withdrawalSigners[_withdrawalId].push(msg.sender);
    }
  }

  /**
   * Request signature again, in case the withdrawer didn't submit to mainchain in time and the set of the validator
   * has changed. Later on this should require some penaties, e.g some money.
   */
  function requestSignatureAgain(uint256 _withdrawalId) public whenNotPaused {
    WithdrawalEntry memory _entry = withdrawals[_withdrawalId];

    require(_entry.owner == msg.sender, "SidechainGatewayManager: sender is not entry owner");

    emit RequestTokenWithdrawalSigAgain(
      _withdrawalId,
      _entry.owner,
      _entry.tokenAddress,
      _entry.mainchainAddress,
      _entry.standard,
      _entry.tokenNumber
    );
  }

  function getPendingWithdrawals(address _owner)
    public
    view
    returns (uint256[] memory ids, WithdrawalEntry[] memory entries)
  {
    ids = pendingWithdrawals[_owner];
    entries = new WithdrawalEntry[](ids.length);

    for (uint256 _i = 0; _i < ids.length; _i++) {
      WithdrawalEntry memory _entry = withdrawals[ids[_i]];
      entries[_i] = _entry;
    }
  }

  function acknowledWithdrawalOnMainchain(uint256 _withdrawalId) public whenNotPaused onlyValidator {
    bytes32 _hash = keccak256(abi.encode(_withdrawalId));
    Acknowledgement.Status _status = _getAcknowledgementContract().acknowledge(
      _getWithdrawalAckChannel(),
      _withdrawalId,
      _hash,
      msg.sender
    );

    if (_status == Acknowledgement.Status.FirstApproved) {
      // Remove out of the pending withdrawals
      WithdrawalEntry storage _entry = withdrawals[_withdrawalId];
      uint256[] storage _ids = pendingWithdrawals[_entry.owner];
      uint256 _len = _ids.length;
      for (uint256 _i = 0; _i < _len; _i++) {
        if (_ids[_i] == _withdrawalId) {
          _ids[_i] = _ids[_len - 1];
          _ids.length--;
          break;
        }
      }
    }
  }

  function getWithdrawalSigners(uint256 _withdrawalId) public view returns (address[] memory) {
    return withdrawalSigners[_withdrawalId];
  }

  function getWithdrawalSignatures(uint256 _withdrawalId)
    public
    view
    returns (address[] memory _signers, bytes[] memory _sigs)
  {
    _signers = getWithdrawalSigners(_withdrawalId);
    _sigs = new bytes[](_signers.length);
    for (uint256 _i = 0; _i < _signers.length; _i++) {
      _sigs[_i] = withdrawalSig[_withdrawalId][_signers[_i]];
    }
  }

  function _depositERC20For(
    address _owner,
    address _token,
    uint256 _amount
  ) internal {
    uint256 _gatewayBalance = IERC20(_token).balanceOf(address(this));
    if (_gatewayBalance < _amount) {
      require(
        IERC20Mintable(_token).mint(address(this), _amount.sub(_gatewayBalance)),
        "SidechainGatewayManager: Minting ERC20 to gateway failed"
      );
    }

    require(IERC20(_token).transfer(_owner, _amount), "SidechainGatewayManager: Transfer ERC20 token failed");
  }

  function _depositERC721For(
    address _owner,
    address _token,
    uint256 _tokenId
  ) internal {
    if (!_tryERC721TransferFrom(_token, address(this), _owner, _tokenId)) {
      require(
        IERC721Mintable(_token).mint(_owner, _tokenId),
        "SidechainGatewayManager: Minting ERC721 token to gateway failed"
      );
    }
  }

  function _alreadyReleased(uint256 _depositId) internal view returns (bool) {
    return deposits[_depositId].owner != address(0) || deposits[_depositId].tokenAddress != address(0);
  }

  function _createWithdrawalEntry(
    address _owner,
    address _token,
    uint32 _standard,
    uint256 _number
  ) internal onlyMappedToken(_token, _standard) returns (uint256 _withdrawalId) {
    (address _mainchainToken, , ) = registry.getMappedToken(_token, false);

    WithdrawalEntry memory _entry = WithdrawalEntry(_owner, _token, _mainchainToken, _standard, _number);

    _withdrawalId = withdrawalCount;
    withdrawals.push(_entry);
    withdrawalCount++;

    pendingWithdrawals[_owner].push(_withdrawalId);

    require(
      pendingWithdrawals[_owner].length <= maxPendingWithdrawal,
      "SidechainGatewayManager: pending withdrawal quantity reached the limit"
    );

    emit TokenWithdrew(_withdrawalId, _owner, _token, _mainchainToken, _standard, _number);
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
