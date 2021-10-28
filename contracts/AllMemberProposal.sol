pragma solidity ^0.4.11;

import './IMemberProposal.sol';

/** A Proposal that requires approval by all members. */
contract AllMemberProposal is IMemberProposal {

  address[] public members;

  /** Returns true if all members have approved the proposal. */
  function isApproved() public constant returns(bool) {
    for(uint i=0; i<members.length; i++) {
      if(!super.isApprovedByMember(members[i])) {
        return false;
      }
    }
    return true;
  }
}
