pragma solidity ^0.5.17;

import "@axie/contract-library/contracts/token/erc20/ERC20Mintable.sol";


contract ERC20SpenderWhitelist is ERC20Mintable {
  event SpenderWhitelisted(address indexed _spender);
  event SpenderUnwhitelisted(address indexed _spender);

  mapping(address => bool) public whitelisted;

  function whitelist(address _spender)
    external
    onlyAdmin
  {
    whitelisted[_spender] = true;
    emit SpenderWhitelisted(_spender);
  }

  function unwhitelist(address _spender)
    external
    onlyAdmin
  {
    delete whitelisted[_spender];
    emit SpenderUnwhitelisted(_spender);
  }

  function allowance(address _owner, address _spender)
    external
    view
    returns (uint256 _value)
  {
    if (whitelisted[_spender]) {
      return uint256(-1);
    }

    return allowances[_owner][_spender];
  }

  function transferFrom(
    address _from,
    address _to,
    uint256 _value
  )
    public
    returns (bool _success)
  {
    require(_to != address(0));

    balanceOf[_from] = balanceOf[_from].sub(_value);
    balanceOf[_to] = balanceOf[_to].add(_value);

    if (!whitelisted[msg.sender]) {
      allowances[_from][msg.sender] = allowances[_from][msg.sender].sub(_value);
    }

    emit Transfer(_from, _to, _value);
    return true;
  }
}
