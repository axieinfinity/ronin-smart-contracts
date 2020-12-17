# ronin-smart-contracts

The smart contract system to power Ronin functionalities

## Validators
Only validators can produce block on Ronin. The validator also acknowledge the deposit event and withdrawal event to faciliate assets transferring. In validator contract, there is a threshold setting indicating that an event needs to have at least that ratio of acknowledgment from validators, whether it is Adding/Removing validator, deposit or withdraw assets. There should be 1 validator contract on Ethereum and 1 validator contract on Ronin. One admin (later on this will be a multi-sig wallet) will have the right to manage validators on Ethereum, the events will be relayed into Ronin thanks to the Bridge component.

## Bridge with Ethereum
When an event happens on Ethereum, the Bridge component in each validator node will pick it up and relay to Ronin by sending a transaction to a smart contract. Depends on the action, it can send the transaction to SideChainValidator (changes in the validator list, update threshold) or SidechainGatewayManager (deposits, withdrawals)

If there are enough acknowledgements (# of acknowledgement/# of validator >= ratio), the event will take effect on Ronin. E.g. confirm a deposit, add one more validator, etc. Below are the example flows of addinging a validator, making a deposit, and making a withdrawal.

### Add one more validator
An admin account will need to send a transaction to add the new validator to MainchainValidator. After that the Bridge in each validator node will acknowlege and approve the new validator. After enough acknowledgements, the new validator can start proposing blocks.

### Deposit
Users deposit ETH, ERC20, ERC721 by sending transaction into MainchainGatewayManager, and wait for the deposit to be acknowledged on Ronin. The gateway should have a mapping between token contracts on Ethereum and on Ronin before the deposit can take place.

### Withdrawal
Similar to deposits, there should be a mapping before users can withdraw. However instead of sending a relay transaction on Ethereum, the validators just provide a signature that the withdrawal event actually happended. The users then need to collect enough signatures and submit to claim the token on Ethereum by themselves.
