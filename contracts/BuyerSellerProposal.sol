pragma solidity ^0.4.11;

import './AllMemberProposal.sol';

/** A Proposal that requires approval by a buyer and seller. */
contract BuyerSellerProposal is AllMemberProposal {

  function BuyerSellerProposal(address buyer, address seller) {
    members = new address[](2);
    members[0] = buyer;
    members[1] = seller;
  }

  /** Sets or changes the buyer (they keep their approval). */
  function setBuyer(address buyer) public onlyowner {
    approvals[buyer] = approvals[members[0]];
    members[0] = buyer;
  }

  /** Sets or changes the seller (they keep their approval). */
  function setSeller(address seller) public onlyowner {
    approvals[seller] = approvals[members[1]];
    members[1] = seller;
  }

  /** Checks if the buyer has approved the proposal. */
  function buyerApproved() public constant returns(bool) {
    return super.isApprovedByMember(members[0]);
  }

  /** Checks if the seller has approved the proposal. */
  function sellerApproved() public constant returns(bool) {
    return super.isApprovedByMember(members[1]);
  }
}
