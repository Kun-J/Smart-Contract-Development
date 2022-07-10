//SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

contract Storage{

  uint public birthyear;
  string public name;

  function set(uint _birthyear, string memory _name) public {
    birthyear = _birthyear;
    name = _name;
  }

  function show() public view returns(uint,string){
    return birthyear;
    return name;
  }
}
