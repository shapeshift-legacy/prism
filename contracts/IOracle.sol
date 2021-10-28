pragma solidity ^0.4.11;

contract IOracle {

  event LogUpdate();
  function get(bytes8 key) public view returns (uint bid, uint ask, uint64 updated);

}