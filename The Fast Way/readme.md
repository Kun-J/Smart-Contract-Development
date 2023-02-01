# **The Fast Way**
## Blockchain Assignment

### **Problem Statement**: 
- *Create a Staking contract which provides auto compounding rewards.*
- *Write test cases for the smart contract.*

### **Features of the Staking Contract**
- *Locked Stakes*: To prevent users from claiming rewards immediately after staking, a time-lock period is added. This would require users to wait a certain amount of time before being able to claim rewards.
- *Auto-Compounding Rewards*: Rewards claimed are automatically staked for a better APY for the user.
- *Whitelist/Blacklist*: To prevent unauthorized or malicious parties from interacting with the contract, a whitelisting system is implemented. 
- *Mutex Design Pattern*: To prevent Reentrancy attack, it does not allow external contracts to call its functions recursively. Openzeppelin's ReentrancyGuard can also be used
- *Pausable Contract*: To allow the contract owner to temporarily halt all contract functionality in case of an emergency or security vulnerability. This is a mechanism that allows a smart contract to be paused in the case of unexpected events, such as a bug or exploit, and can help prevent further damage or loss. 
- *Access Control*: Only admin can perform certain actions in the contract.
