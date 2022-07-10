//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Condition{

  function check(uint x) public view returns(uint){
    if(x<10){
      return 0;
    } else if (x>10){
      return 1;
    }else {
      return 2;
    }
  }
  function ternary(uint _x) public view returns(uint){
    return _x<10 ? 0 : 1;
  }
}
