pragma solidity ^0.4.11;

import './Owned.sol';

/** An extension to Owned that allows multiple owners (but not multiple roles). With the multisig modifier, permission is granted to ANY of the owners to invoke the method. */
contract MultiSig is Owned {

  /** Only allow if msg.sender is a authorized. */
  modifier multisig { if (!sigs[msg.sender]) revert(); _; }

  /** A mapping of authorized addresses. */
  mapping(address => bool) sigs;

  /** Auhorize an address. */
  function addSig(address account) public onlyowner {
    sigs[account] = true;
  }

  /** Remove authorization for an address. */
  function removeSig(address account) public onlyowner {
    sigs[account] = false;
  }
}
