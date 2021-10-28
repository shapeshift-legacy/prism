pragma solidity ^0.4.11;

import './PrismLibData.sol';
import './IPrism.sol';

library PrismLib {

  using AccountLib for AccountLib.Data;
  using FollowerManagerLib for FollowerManagerLib.Data;
  using PortfolioLib for PortfolioLib.Data;
  using RebalancerLib for RebalancerLib.Data;
  using Relay for Relay.Data;

  /*************************************************
   * Functions
   *************************************************/

  // NOTE: do not confuse with rebalancerLib.proposeRebalance
  /*
    uints[0] = _principal
    uints[1] = _buyerCollateralRatio
    uints[2] = _sellerCollateralRatio
  */
  function proposeRebalance(PrismLibData.Data storage self, uint[] uints, bytes8[] tickers, uint[] amounts, address registrar) public {
    // auth
    if (self.state != PrismLibData.State.Accepted) revert();
    if (msg.sender != self.accountLib.buyer && msg.sender != self.accountLib.seller) revert();

    // cannot not rebalance if following
    if (self.followerManagerLib.hasLeader()) revert();

    self.rebalancerLib.proposeRebalance(self.relay, self.logger, self.accountLib.buyer, self.accountLib.seller, uints, tickers, amounts, registrar);

    // the sender who is proposing the rebalance implicitly approves it
    self.rebalancerLib.approveAsMember(msg.sender);

    // deposit any funds that are sent, such as for increasing the principal
    self.accountLib.depositTo(msg.sender);
  }

  // allow sender to be set explicitly so we can alias relays to buyer and seller
  function approveRebalance(PrismLibData.Data storage self, uint nonce) public {

    // lock
    if (self.locked) revert();
    self.locked = true;

    if (self.rebalancerLib.nonce != nonce) revert();

    // allow relays to be aliases for buyer or seller
    bool isBuyerRelay = msg.sender == self.relay.getRelay(IPrism(0x0).approveRebalance.selector, self.accountLib.buyer);
    bool isSellerRelay = msg.sender == self.relay.getRelay(IPrism(0x0).approveRebalance.selector, self.accountLib.seller);
    address sender =
      isBuyerRelay ? self.accountLib.buyer :
      isSellerRelay ? self.accountLib.seller :
      msg.sender;

    // if the sender is not the buyer or seller, it will not affect isApproved()
    self.accountLib.depositTo(sender);
    self.rebalancerLib.approveAsMember(sender);
    self.rebalancerLib.tryRebalance(self.portfolioLib, self.accountLib, self.logger, nonce);

    // unlock
    self.locked = false;
  }
}
