//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ToDo{

  struct activity{
    string public text;
    bool status;
  }
activity[] public todos;

function create(string memory _text) public {
  todos.push(activity(_text, false));
}
function completion (uint _index) public {
  activity storage todo = todos[_index];
  todo.status=!todo.status;
}
}
