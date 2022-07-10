//SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

contract Loop{

  function loop() public {
    for (uint i=0; i<10;i++){
      if(i==2){
        continue;
      }
      if(i==4){
        break;
      }
    }
  }
}
