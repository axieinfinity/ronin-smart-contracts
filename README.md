# ronin-smart-contracts

The smart contract system to power Ronin functionalities

## Validators
Only validators can produce block on Ronin. The validator also acknowledge the deposit event and withdrawal event to faciliate assets transferring. In validator contract, there is a threshold setting indicating that an event needs to have at least that ratio to be confirmed at actually happend, whether it is Adding/Removing validator, deposit or withdraw assets. There should be 1 validator contract on Ethereum and 1 validator contract on Ronin. One admin (later on this will be a multi-sig account) will have the right to manage validators on Ethereum, the events will be relayed into Ronin thanks to the Bridge component.

## Bridge with Ethereum
When an event happens on Ethereum, the Bridge component in each validator node will pick it up and relay to a smart contract on Ronin.

If there are enough acknowledgements, the event will take the effect on Ronin. E.g. confirm a deposit, add one more validator, etc. Below are the example flows of addinging a validator, making a deposit and a withdrawal.

### Add one more validator
An admin account will need to send a transaction to add the new validator. After that the current validator list will acknowledge and approve the new validator. After enough acknowledgement the new validator can start proposing blocks.

### Deposit
Users deposit ETH, ERC20, ERC721 by sending transaction into MainchainGatewayManager, and wait for the deposit to be acknowledged on Ronin. The gateway should have a mapping between token contracts on Ethereum and on Ronin before the deposit can take place.

### Withdrawal
Similar to deposits, there should be a mapping before users can withdraw. However instead of sending a relay transaction on Ethereum, the validators just provide a signature that the withdrawal event actually happended. The users then need to collect enough signatures and submit to claim the token on Ethereum by themselves.
