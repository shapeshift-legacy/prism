pragma solidity ^0.4.11;

import './Owned.sol';

/** A generic registrar that maps names to addresses. */
contract Registrar is Owned {

  mapping (bytes32 => address) public registry;

  event NewEntry(bytes32 name, address location);

  function addToRegistry(bytes32 name, address location) public onlyowner {
    registry[name] = location;
    NewEntry(name, location);
  }
}
