//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AdvMapping {

  mapping (address => mapping (uint => bool ) public advmap;

  function set(address _add, uint _r, bool _b) public {
    advmap[_add][_r] = _b;
  }
  function remove(address _add) public {
    delete advmap[_add][_r];
  }
}
