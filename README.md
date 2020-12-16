# ronin-smart-contracts

The smart contract system to power Ronin functionalities

## Bridge with Ethereum
When an event happens on Ethereum, the Bridge component in each validator node will pick it up and relay to a smart contract on Ronin.

If there are enough acknowledgements, the event will take the effect on Ronin. E.g. confirm a deposit, add one more validator, etc. Below are the flows of deposit and withdrawals.

### Deposit
Users deposit ETH, ERC20, ERC721 by sending transaction into MainchainGatewayManager, and wait for the deposit to be acknowledged on Ronin. The gateway should have a mapping between contracts on Ethereum and on Ronin before the deposit can take place.

### Withdrawal
Similar to deposits, there should be a mapping before users can withdraw. However instead of sending a relay txs on Ethereum, the validators just provide a signature that the withdrawal event actually happended. The users then need to collect enough signatures and submit to claim the token on Ethereum by themselves.
