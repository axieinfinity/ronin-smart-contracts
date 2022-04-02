// SPDX-License-Identifier: MIT
pragma solidity ^0.5.2;

interface IERC721 {
  event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
  event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
  event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

  function balanceOf(address _owner) external view returns (uint256 _balance);

  function ownerOf(uint256 _tokenId) external view returns (address _owner);

  function approve(address _to, uint256 _tokenId) external;

  function getApproved(uint256 _tokenId) external view returns (address _operator);

  function setApprovalForAll(address _operator, bool _approved) external;

  function isApprovedForAll(address _owner, address _operator) external view returns (bool _approved);

  function transferFrom(
    address _from,
    address _to,
    uint256 _tokenId
  ) external;

  function safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId
  ) external;

  function safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId,
    bytes calldata _data
  ) external;
}
