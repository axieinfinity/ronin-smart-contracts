pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/token/erc20/IERC20.sol";

contract IWETH is IERC20 {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    function deposit() external payable;
    function withdraw(uint256 wad) external;
}
