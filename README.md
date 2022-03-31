##**Ronin-Smart-Contracts**

The smart contracts that power Ronin.

## **Validators**

Only validators can produce blocks on Ronin. Validators can also acknowledge deposit and withdrawal events to facilitate asset transfers.

Each validator contract has a minimum threshold that must be reached when the state changes such as transfer of assets and addition/removal of validators. There is one validator contract on Ethereum and a corresponding validator contract on Ronin. An admin has the right to manage validators on Ethereum (in the future this will be upgraded to a multi-sig walllet). These changes are relayed to Ronin through the Bridge component.

## Ethereum Bridge

When an event happens on Ethereum, the Bridge component in each validator node will pick it up and relay it to Ronin by sending a corresponding transaction.

Depending on the action, these transactions will be relayed to *SideChainValidator* (changes in the validator list/updates to the consensus threshold) or *SidechainGatewayManager* (deposits, withdrawals).

If there are enough acknowledgements (# of acknowledgement/# of validator >= ratio), the event will be confirmed on Ronin.

### **Adding Validators**

An admin account will need to send a transaction to add the new validator to *MainchainValidator*. Next, the Bridge in each validator node will acknowledge and approve the new validator. After having enough acknowledgements, the new validator can start proposing blocks.

### **Deposits**

Users can deposit ETH, ERC20, and ERC721 (NFTs) by sending transactions to *MainchainGatewayManager* and waiting for the deposit to be verified on Ronin. The gateway should have a mapping between token contracts on Ethereum and on Ronin before the deposit can take place.

### **Withdrawals**

Similar to deposits, there should be token mapping between Ronin and Ethereum before users can withdraw. However, instead of sending a relay transaction on Ethereum, the validators simply provide a signature that the withdrawal event has taken place. The withdrawal then needs to collect enough signatures before it can be claimed by the user on Ethereum.
