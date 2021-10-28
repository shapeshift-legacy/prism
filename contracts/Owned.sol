pragma solidity ^0.4.11;

/** A simple contract that sets the contract creator to the owner, provides an access control modifier, and provides the ability to change owners. */
contract Owned {

  /** Only allow if msg.sender is the owner. */
  modifier onlyowner { if (msg.sender != owner) revert(); _; }

  address public owner;

  function Owned() {
    owner = msg.sender;
  }

  /** Transfers the contract to a different owner. */
  function transferOwner(address newOwner) onlyowner {
    owner = newOwner;
  }
}
