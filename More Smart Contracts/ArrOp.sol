//SPDX-License-Identifier: MIT
pragma solidity ^0.8.8

contract ArrayOperations{

  uint[] public arr;

  function add(uint i) public {
    arr.push(i);
  }
  function deleteLastElement() public {
    arr.pop();
  }
  function deleteElementValue(uint index) public {
    delete arr[index];
  }
  function arrLength() public view returns {
    return arr.length;
  }
  function removeElement(uint index) public {
    require(index < arr.length,'Index not present');
    for (uint i =0 ; i<arr.length; i++){
      if(i==index){
        arr[i] = arr[arr.length-1];
        arr.pop();
        break;
      }
    }
  }
}
