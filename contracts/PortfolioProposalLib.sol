pragma solidity ^0.4.11;

/** A Proposal for an initial offer requiring approval by a buyer and seller. */
library PortfolioProposalLib {

  struct Data {
    // time in seconds after an offer is made that the buyer can approve the proposal
    uint timespanOffer;

    // time in seconds from acceptance time when the buyer is allowed to settle
    uint timespanBeforeSettle;

    // time in seconds from buyer settle request to when prism can be settled and funds can be withdrawn
    uint timespanBeforeWithdraw;

    // time in seconds before the seller can liquidate the portfolio
    uint timespanDuration;

    // time created
    uint created;

    // closing fees
    uint closingFeePercentBuyer;
    uint closingFeePercentSeller;
    uint closingFeeFixedBuyer;
    uint closingFeeFixedSeller;

    // rebalance fees
    uint rebalanceFeePercentToSeller;
    uint rebalanceFeePercentToOwner;
    uint rebalanceFeeFixedToSeller;
    uint rebalanceFeeFixedToOwner;


    // the initial fee to the seller that can be immediately withdrawn after the prism becomes Accepted
    uint initialCommission;

    // the % of principal in ETH that is paid daily to the seller. It can be withdrawn at a pro-rated rate at any time.
    // NOTE: This is given a % of principal here, but is converted into a fixed amount of ETH in the PrismAccount.
    // NOTE: stored as an integer that will be divided by fixedPrecision to simulate a fixed point number of a given precision
    uint dailyCommission;

    // collateral required from the buyer and seller to accept the contract as a percentage of the value
    // also determines how much funds the buyer or seller can withdraw if overcollateralized
    // NOTE: stored as an integer that will be divided by fixedPrecision to simulate a fixed point number of a given precision
    uint buyerCollateralRatio;
    uint sellerCollateralRatio;
  }

  /** Create proposal and do not let the offer be changed */
  function createProposal(Data storage self, uint[4] uints, uint[4] timespans, uint[8] fees) internal {
    if (self.created > 0) revert();

    self.initialCommission = uints[0];
    self.dailyCommission = uints[1];
    self.buyerCollateralRatio = uints[2];
    self.sellerCollateralRatio = uints[3];
    self.timespanOffer = timespans[0];
    self.timespanBeforeSettle = timespans[1];
    self.timespanDuration = timespans[2];
    self.timespanBeforeWithdraw = timespans[3];
    self.created = now;
    self.closingFeePercentBuyer = fees[0];
    self.closingFeePercentSeller = fees[1];
    self.closingFeeFixedBuyer = fees[2];
    self.closingFeeFixedSeller = fees[3];
    self.rebalanceFeePercentToSeller = fees[4];
    self.rebalanceFeePercentToOwner = fees[5];
    self.rebalanceFeeFixedToSeller = fees[6];
    self.rebalanceFeeFixedToOwner = fees[7];
  }
}
