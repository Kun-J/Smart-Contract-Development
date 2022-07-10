//SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.0.0/contracts/token/ERC20/ERC20.sol";

contract PersonalToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
      mint(msg.sender, 100 * 10**uint(decimals()));
    }
}
