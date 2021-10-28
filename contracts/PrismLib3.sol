pragma solidity ^0.4.19;

import './PrismLibData.sol';
import './PrismLib2.sol';
import './DecimalMath.sol';
import './IPrism.sol';

// factor out functionality from PrismLib to reduce deployed bytecode
library PrismLib3 {

  using Relay for Relay.Data;
  using AccountLib for AccountLib.Data;
  using FollowerManagerLib for FollowerManagerLib.Data;
  using PortfolioLib for PortfolioLib.Data;
  using PortfolioProposalLib for PortfolioProposalLib.Data;
  using PrismLib2 for PrismLibData.Data;

  /*************************************************
   * Internal Helper Functions
   *************************************************/

  /** Returns true if the prism has a leader. */
  function hasLeader(PrismLibData.Data self) internal constant returns (bool) {
    return address(self.followerManagerLib.leaderPrism) != 0x0;
  }

  /*************************************************
   * Functions
   *************************************************/

  // NOTE: prismData.setRelays cannot be called within the constructor since
  // prism's address is not yet determined.
  function initRelayFactory(PrismLibData.Data storage self, address factory, address target) public {
    // auth
    if (self.state != PrismLibData.State.Open) revert();
    if (msg.sender != self.accountLib.owner) revert();
    if (factory == 0x0) revert();
    if (target == 0x0) revert();

    // only to be called once
    if (self.relay.factory != 0x0 || self.relay.target != 0x0) revert();

    self.relay.factory = factory;
    self.relay.target = target;
  }

  /** The fallback function is PrismLibData.Data storage self, called when funds are sent directly to the contract address. Note: Keep gas usage minimal as all transfers that do not send enough gas will fail. */
  function fallback(PrismLibData.Data storage self) public {

    if (self.accountLib.buyer != msg.sender && self.accountLib.seller != msg.sender) revert();

    self.accountLib.depositTo(msg.sender);

    tryAccept(self);
  }

  /** Sets all the relay addresses to the current buyer. */
  function setRelays(PrismLibData.Data storage self) internal {
    self.relay.addRelay(IPrism(0x0).buyerSettleCommit.selector, self.accountLib.buyer, 0x0);
  }

  /** Returns all the relay addresses. Unique rebalance relays are generated per proposal. */
  function getRelays(PrismLibData.Data storage self) public constant returns(address) {
    return (
      self.relay.getRelay(IPrism(0x0).buyerSettleCommit.selector, self.accountLib.buyer)
    );
  }

  /** Allow the buyer to transfer to another account. */
  function transferBuyer(PrismLibData.Data storage self, address newBuyer) public {
    // auth
    if (msg.sender != self.accountLib.buyer) revert();

    self.accountLib.setBuyer(newBuyer);

    setRelays(self);
  }

  /** Allow the seller to transfer to another account. */
  function transferSeller(PrismLibData.Data storage self, address newSeller) public {
    // auth
    if (msg.sender != self.accountLib.seller) revert();

    self.accountLib.setSeller(newSeller);
  }

  /** Allow the buyer to transfer to another account. */
  function transferOwner(PrismLibData.Data storage self, address newOwner) public {
    // auth
    if (msg.sender != self.accountLib.owner) revert();

    self.accountLib.setOwner(newOwner);
  }

  /** Allow the override to transfer to another account. */
  function transferOverride(PrismLibData.Data storage self, address newOverride) public {
    // auth
    if (msg.sender != self.override) revert();

    self.override = newOverride;
  }

  /** Make an offer as the seller. If the buyer accepts, the contract will enter an Accepted PrismLibData.state. */
  /*
    Use Array params to pass in data without exceeding call stack

    Indices:
      uints[0] = _initialCommission
      uints[1] = _dailyCommission
      uints[2] = _buyerCollateralRatio
      uints[3] = _sellerCollateralRatio

      timespans[0] = _timespanOffer
      timespans[1] = _timespanBeforeSettle
      timespans[2] = _timespanDuration

      fees[0] = _closingFeePercentBuyer
      fees[1] = _closingFeePercentSeller
      fees[2] = _closingFeeFixedBuyer
      fees[3] = _closingFeeFixedSeller
      fees[4] = _rebalanceFeePercentToSeller
      fees[5] = _rebalanceFeePercentToOwner
      fees[6] = _rebalanceFeeFixedToSeller
      fees[7] = _rebalanceFeeFixedToOwner
  */
  function offer(PrismLibData.Data storage self, uint[4] uints, uint[4] timespans, uint[8] fees) public {

    // auth
    if (self.state != PrismLibData.State.Open) revert();
    if (msg.sender != self.accountLib.seller) revert();

    // create proposal offer which cannot be changed
    self.portfolioProposalLib.createProposal(uints, timespans, fees);

    // allow the seller to send funds in the offer
    // they may also send funds directly to the contract (fallback function)
    self.accountLib.depositToSeller();

    // attempt to accept the contract in case the buyer has already contributed funds
    tryAccept(self);
  }

  /** Withdraw available seller funds. If Accepted, withdraws initial commission and a pro-rated amount of daily commission. If Settled, withdraws collateral. */
  function sellerWithdraw(PrismLibData.Data storage self) public {
    // Open: withdraw all seller funds (not including commission, which is only transferred to the seller after the contract becomes Accepted)
    if (self.state == PrismLibData.State.Open) {
      self.accountLib.sellerWithdraw(self.accountLib.seller, self.accountLib.sellerFunds());
    }
    // Accepted: subscription
    else if (self.state == PrismLibData.State.Accepted) {
      // allow the seller to withdraw commissions (i.e. everything except collateral)
      // sellerFunds() will automatically transfer the pro-rated dailyCommission before returning the current balance
      uint sellerCollateral = SafeMath.multiply(DecimalMath.fromFixed(self.portfolioLib.principal), self.portfolioLib.sellerCollateralRatio);
      self.accountLib.sellerWithdraw(self.accountLib.seller, SafeMath.subtract(self.accountLib.sellerFunds(), sellerCollateral));
    }
    // Settled: withdraw finalValue
    else if (self.state == PrismLibData.State.Settled) {
      // now that funds have been aportioned appropriately, withdraw all the seller's funds
      self.accountLib.sellerWithdraw(self.accountLib.seller, self.accountLib.sellerFunds());
    }
    // Note: No state change for Prism state == Aborted
  }

  /* Tries to activate the contract if sufficient collateral has been posted by all parties and all criteria have been met. Must have a buyer and a seller (implicitly true if self.accountLib.buyerFunds() and self.accountLib.sellerFunds() are non-empty). Do not throw since this is called from the fallback function. */
  function tryAccept(PrismLibData.Data storage self) public {

    if (self.portfolioProposalLib.created == 0) return;

    if (!verifyAccept(self, self.state == PrismLibData.State.Open,
      self.portfolioLib.principal,
      self.portfolioProposalLib.initialCommission,
      self.portfolioProposalLib.created,
      self.portfolioProposalLib.timespanOffer,
      DecimalMath.fromFixed(SafeMath.multiply(self.portfolioProposalLib.buyerCollateralRatio, self.portfolioLib.principal)),
      DecimalMath.fromFixed(SafeMath.multiply(self.portfolioProposalLib.sellerCollateralRatio, self.portfolioLib.principal))
    )) return;

    self.state = PrismLibData.State.Accepted;

    // transfer values from proposal offer to portfolio
    self.portfolioLib.transferProposal(self.portfolioProposalLib);

    // convert daily commission from a % of principal to fixed amount of ETH
    uint dailyCommission = SafeMath.multiply(DecimalMath.fromFixed(self.portfolioLib.principal), self.portfolioProposalLib.dailyCommission);

    // accept proposal with initial start values
    self.accountLib.acceptProposal(now, self.portfolioProposalLib.initialCommission, dailyCommission);

    self.timespanOffer = self.portfolioProposalLib.timespanOffer;
    self.timespanBeforeSettle = self.portfolioProposalLib.timespanBeforeSettle;
    self.timespanDuration = self.portfolioProposalLib.timespanDuration;
    self.timespanBeforeWithdraw = self.portfolioProposalLib.timespanBeforeWithdraw;

    // transfer initial commission to seller
    self.accountLib.transfer(self.accountLib.buyer, self.accountLib.seller, self.accountLib.initialCommission);

    self.logger.logStateChange(uint(PrismLibData.State.Accepted), now);
  }

  function verifyAccept(PrismLibData.Data storage self, bool open, uint principal, uint initialCommission, uint timeOffered, uint _timespanOffer, uint buyerCollateral, uint sellerCollateral) internal constant returns(bool) {

    if (
      // contract is not open.
      !open ||
      // no offer has been made
      timeOffered == 0 ||
      // offer has expired.
      now > SafeMath.add(timeOffered, _timespanOffer) ||
      // insufficient seller collateral.
      self.accountLib.sellerFunds() < sellerCollateral ||
      // insufficient buyer funds (principal, buyerCollateral, and initialCommission).
      self.accountLib.buyerFunds() < SafeMath.add(principal, buyerCollateral,  initialCommission)
    ) {
      return false;
    }

    return true;
  }

  /** A bundled getter for many member variables. This is done to reduce the bytecode size of having multiple individual getters. */
  function data(PrismLibData.Data storage self) public returns(uint, address[5], uint[29], bool[1]) {

    // indices are commented below for convenience since these are returned as arrays
    return (
    uint(self.state),
    [
    /*  0 */self.accountLib.buyer,
    /*  1 */self.accountLib.seller,
    /*  2 */self.portfolioLib.registrar,
    /*  3 */self.override,
    /*  4 */self.followerManagerLib.leaderPrism
    ],
    [
    /*  0 */self.portfolioLib.principal,
    /*  1 */self.calculateValue(),
    /*  2 */self.portfolioLib.finalValue,
    /*  3 */self.accountLib.initialCommission,
    /*  4 */self.accountLib.dailyCommission,
    /*  5 */self.portfolioLib.buyerCollateralRatio,
    /*  6 */self.portfolioLib.sellerCollateralRatio,
    /*  7 */self.rebalancerLib.rebalanceFrequency,
    /*  8 */self.portfolioProposalLib.created,
    /*  9 */self.accountLib.startTime,
    /* 10 */self.accountLib.endTime,
    /* 11 */self.timespanOffer,
    /* 12 */self.timespanBeforeSettle,
    /* 13 */self.followerManagerLib.followFee,
    /* 14 */self.followerManagerLib.minFollowerPrincipal,
    /* 15 */self.accountLib.buyerFunds(),
    /* 16 */self.accountLib.sellerFunds(),
    /* 17 */self.accountLib.ownerFunds(),
    /* 18 */self.timespanDuration,
    /* 19 */self.portfolioProposalLib.closingFeePercentBuyer,
    /* 20 */self.portfolioProposalLib.closingFeePercentSeller,
    /* 21 */self.portfolioProposalLib.closingFeeFixedBuyer,
    /* 22 */self.portfolioProposalLib.closingFeeFixedSeller,
    /* 23 */self.portfolioProposalLib.rebalanceFeePercentToSeller,
    /* 24 */self.portfolioProposalLib.rebalanceFeePercentToOwner,
    /* 25 */self.portfolioProposalLib.rebalanceFeeFixedToSeller,
    /* 26 */self.portfolioProposalLib.rebalanceFeeFixedToOwner,
    /* 27 */self.timespanBeforeWithdraw,
    /* 28 */self.lastUpdate()
    ],
    /* bool*/[self.followerManagerLib.settleWithLeader]
    );
  }
}
