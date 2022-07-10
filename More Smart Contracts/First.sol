//SPDX-License-Identifier : MIT
pragma solidity ^0.8.0;

contract IncDecCounter {

  uint16 public counter;

  function increment() public {
    counter+=1;
  }
  function decrement() public {
    counter-=1;
  }
  function getCounter() public view returns(uint16){
    return counter;
  }
}
