pragma solidity ^0.4.11;

import './IProposal.sol';
import './Owned.sol';

/** A Proposal interface involving approval by one or more members. */
contract IMemberProposal is IProposal, Owned {

  mapping(address => bool) approvals;

  /** Returns whether the given member has approved the proposal. */
  function isApprovedByMember(address member) public constant returns(bool) {
    return approvals[member];
  }

  /** Approves the proposal by the sender. */
  function approve() public {
    approvals[msg.sender] = true;
  }

  /** The owner can force approval by a member. */
  /** Owner refers to the contract creator which will be the prism contract */
  function approveAsMember(address member) public onlyowner {
    approvals[member] = true;
  }

  // ABSTRACT
  function isApproved() public constant returns(bool);
}
