//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EthWallet {

  address payable public owner ;

  constructor (){
    owner = payable (msg.sender);
  }
  receive () external payable {}

  function withdraw(uint _amount) external {
    require ( msg.sender==owner, 'Not called by Owner');
    payable(msg.sender).transfer(_amount);
  }
  function balance() external view returns (uint){
    return address(this).balance;
  }
}
