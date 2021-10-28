pragma solidity ^0.4.11;

/** A base interface for a proposal contract. */
contract IProposal {

  /** Allows the sender to approve the proposal */
  function approve() public;

  /** Returns true or false if the proposal has been approved. The requirements for approval are left to be defined by inheriting contracts. */
  function isApproved() public constant returns(bool);
}
