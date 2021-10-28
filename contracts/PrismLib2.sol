pragma solidity ^0.4.11;

import './PrismLibData.sol';
import './SafeMath.sol';
import './IPrism.sol';
import './PrismLogger.sol';
import './DecimalMath.sol';

// factor out functionality from PrismLib to reduce deployed bytecode
library PrismLib2 {

  using Relay for Relay.Data;
  using FollowerManagerLib for FollowerManagerLib.Data;
  using PortfolioLib for PortfolioLib.Data;
  using AccountLib for AccountLib.Data;

  /*************************************************
   * Internal Helper Functions
   *************************************************/

  /** Returns true if the leader exists and has aborted. */
  function leaderAborted(PrismLibData.Data storage self) internal constant returns (bool) {
    if (!self.followerManagerLib.hasLeader()) {
      return false;
    }

    uint leaderState;
    (leaderState,,,) = IPrism(self.followerManagerLib.leaderPrism).data();

    return PrismLibData.State(leaderState) == PrismLibData.State.Aborted;
  }

  /** Returns the principal ratio between self and leader, multiplied by fixedPrecision to simulate fixed point. Returns 1 if leader is not set. */
  function multiplyPrincipalRatio(PrismLibData.Data storage self, uint num) internal constant returns (uint) {

    if (!self.followerManagerLib.hasLeader()) {
      return num;
    }

    // calculate principal ratio between self and leader
    // get leader principal
    uint[29] memory uints;
    (,,uints,) = IPrism(self.followerManagerLib.leaderPrism).data();

    return DecimalMath.fromFixed(SafeMath.multiply(num, DecimalMath.toFixed(self.portfolioLib.principal) / uints[0])); // uints[0] = principal
  }

  /** Returns sellerFunds - buyerProfit. Can be negative. */
  function sellerCollateral(PrismLibData.Data storage self) internal constant returns(int) {
    return int(self.accountLib.sellerFunds()) - (int(calculateValue(self)) - int(self.portfolioLib.principal));
  }

  /** Returns buyerFunds - sellerProfit. Can be negative. */
  function buyerCollateral(PrismLibData.Data storage self) internal constant returns(int) {
    return int(self.accountLib.buyerFunds()) - (int(self.portfolioLib.principal) - int(calculateValue(self)));
  }

  /*************************************************
   * Functions
   *************************************************/

  /** Attempts to settle the prism for the buyer. */
  function buyerSettleCommit(PrismLibData.Data storage self) public {
    // auth
    if (msg.sender != self.accountLib.buyer &&
        msg.sender != self.relay.getRelay(IPrism(0x0).buyerSettleCommit.selector, self.accountLib.buyer)) revert();

    if (self.state != PrismLibData.State.Accepted) revert();
    if (now < self.accountLib.startTime + self.timespanBeforeSettle) revert();

    self.portfolioLib.commitSettle(now, lastUpdate(self), calculateValue(self));

    self.logger.logSettleCommit(self.timespanBeforeWithdraw);
  }

  function buyerSettleConfirm(PrismLibData.Data storage self) public {
    // this function should only trigger if settleTime has been set in buyerSettleCommit()
    // a better solution would be a PreSettle state check
    if (self.portfolioLib.settleTime == 0) revert();
    if (now < self.portfolioLib.settleTime + self.timespanBeforeWithdraw) revert();

    // no auth check - this function is callable by anyone but always withdraws to buyer's address
    uint postFinalTime = lastUpdate(self);
    uint postFinalValue = calculateValue(self);

    uint deltaT = postFinalTime - self.portfolioLib.preFinalTime;
    uint finalValue;
    if (deltaT == 0) {
      // Same oracle update for pre and post updates - use current
      finalValue = postFinalValue;
    } else {
      if (postFinalValue > self.portfolioLib.preFinalValue) {
        finalValue = self.portfolioLib.preFinalValue +
          (self.portfolioLib.settleTime - self.portfolioLib.preFinalTime) *
          (postFinalValue - self.portfolioLib.preFinalValue) / deltaT;
      } else {
        finalValue = postFinalValue + (self.portfolioLib.settleTime - self.portfolioLib.preFinalTime) *
          (self.portfolioLib.preFinalValue - postFinalValue) / deltaT;
      }
    }

    settle(self, finalValue);
    self.state = PrismLibData.State.Settled;
    self.logger.logStateChange(uint(PrismLibData.State.Settled), now);
  }

  // NOTE: During Accepted, this will withdraw all funds beyond the principal, collateral, and one dailyCommission. This could include excess funds that were needed for follower fees. They can be re-added by sending ETH to the Prism.
  function buyerWithdraw(PrismLibData.Data storage self) public {
    if (self.state == PrismLibData.State.Accepted) {
      uint buyerCollateral = SafeMath.multiply(DecimalMath.fromFixed(self.portfolioLib.principal), self.portfolioLib.buyerCollateralRatio);
      // Subtract one dailyCommission to prevent erroring out due to overflow. Not precise.
      self.accountLib.buyerWithdraw(self.accountLib.buyer,
        SafeMath.subtract(self.accountLib.buyerFunds(),
        self.portfolioLib.principal,
        buyerCollateral,
        self.accountLib.dailyCommission));
    }
    else {
      self.accountLib.buyerWithdraw(self.accountLib.buyer, self.accountLib.buyerFunds());
    }
  }

  /** Withdraws any available fees due to owner. */
  function ownerWithdraw(PrismLibData.Data storage self) public {
    self.accountLib.ownerWithdraw(self.accountLib.owner, self.accountLib.ownerFunds());
  }

  /** Allows the self.accountLib.seller to liquidate the contract if the value goes to 0. */
  // INVARIANT: prismProposal has been accepted because were are in an Accepted self.PrismLibData.state.
  function sellerSettle(PrismLibData.Data storage self) {
    // auth
    if (self.state != PrismLibData.State.Accepted) revert();
    if (msg.sender != self.accountLib.seller) revert();

    // allow seller to settle 0 buyer collateral has run out
    // allow seller to settle if seller collateral has run out
    // allow seller to settle after duration
    uint val = calculateValue(self);
    if (buyerCollateral(self) > 0 &&
        sellerCollateral(self) > 0 &&
        now - self.accountLib.startTime < self.timespanDuration) revert();
    settle(self, val);
    self.state = PrismLibData.State.Settled;
    self.logger.logStateChange(uint(PrismLibData.State.Settled), now);
  }

  /** Settles the prism. Warning: Only to be used internally. Does not provide any business logic checks. */
  // NOTE: self.state = Settled must be set by the calling function.
  function settle(PrismLibData.Data storage self, uint finalValue) internal {
    self.portfolioLib.setFinalValue(finalValue);
    self.accountLib.setSettleEndTime(now);

    // allocate the funds appropriately

    /* Owner fee calculations
    */

    // buyer
    // total closing fees = fixedFee + ((feePercentage * finalValue) / fixedPrecision)
    uint totalClosingFeeBuyer = SafeMath.add(self.portfolioLib.closingFeeFixedBuyer, DecimalMath.fromFixed(SafeMath.multiply(self.portfolioLib.closingFeePercentBuyer, finalValue)));
    if (totalClosingFeeBuyer > self.accountLib.buyerFunds()) {
      self.accountLib.transferAll(self.accountLib.buyer, self.accountLib.owner);
    }
    // if seller does not have enough funds, send all available
    else {
      self.accountLib.transfer(self.accountLib.buyer, self.accountLib.owner, totalClosingFeeBuyer);
    }
    // seller
    // total closing fees = fixedFee + ((feePercentage * finalValue) / fixedPrecision)
    uint totalClosingFeeSeller = SafeMath.add(self.portfolioLib.closingFeeFixedSeller, DecimalMath.fromFixed(SafeMath.multiply(self.portfolioLib.closingFeePercentSeller, finalValue)));
    if (totalClosingFeeSeller > self.accountLib.sellerFunds()) {
      self.accountLib.transferAll(self.accountLib.seller, self.accountLib.owner);
    }
    // if buyer does not have enough funds, send all available
    else {
      self.accountLib.transfer(self.accountLib.seller, self.accountLib.owner, totalClosingFeeSeller);
    }

    /* End owner fees
    */

    // buyer profit
    if (finalValue > self.portfolioLib.principal) {
      uint valueGain = SafeMath.subtract(finalValue, self.portfolioLib.principal);
      if (valueGain < self.accountLib.sellerFunds()) {
        self.accountLib.transfer(self.accountLib.seller, self.accountLib.buyer, valueGain);
      }
      // if seller does not have enough funds, send all available
      else {
        self.accountLib.transferAll(self.accountLib.seller, self.accountLib.buyer);
      }
    }
    // seller profit
    else {
      uint valueLost = SafeMath.subtract(self.portfolioLib.principal, finalValue);
      if (valueLost < self.accountLib.buyerFunds()) {
        self.accountLib.transfer(self.accountLib.buyer, self.accountLib.seller, valueLost);
      }
      // if buyer does not have enough funds, send all available
      else {
        self.accountLib.transferAll(self.accountLib.buyer, self.accountLib.seller);
      }
    }

    if (self.followerManagerLib.hasLeader()) {
      withdrawFollowFee(self, finalValue);
    }
  }

  /** Withdraws a percentage of the profit to the leader prism. */
  function withdrawFollowFee(PrismLibData.Data storage self, uint value) internal {
    if (value == 0) return;

    // get leader
    IPrism leaderPrism = IPrism(self.followerManagerLib.leaderPrism);

    // get leader data
    uint[29] memory uints;
    (,,uints,) = IPrism(leaderPrism).data();

    // get leader's follow fee
    if (uints[13] == 0) return; // uints[13] = followFee

    uint profit = SafeMath.subtract(value, self.followStartValue);
    uint followFeeAmount = DecimalMath.fromFixed(SafeMath.multiply(uints[13], profit)); // uints[13] = followFee

    // deposit the follow fee in the leader prism and assign to buyer
    if (followFeeAmount < self.accountLib.buyerFunds()) {
      self.accountLib.buyerWithdrawCall(leaderPrism, followFeeAmount, IPrism(0x0).depositToBuyer.selector);
    }
  }

  /** An override that allows the contract to be aborted and funds drained. */
  function abort(PrismLibData.Data storage self, address to) public {
    if (msg.sender != self.override) revert();
    if (to == 0x0) revert();
    // NOTE: followers marked as settleWithLeader must be aborted manually as the final value of the leader will not be set
    if (self.state == PrismLibData.State.Accepted) {
      self.portfolioLib.setFinalValue(calculateValue(self));
    }
    self.state = PrismLibData.State.Aborted;
    self.accountLib.withdrawAll(to); // mutex prevents re-entry
    self.logger.logStateChange(uint(PrismLibData.State.Aborted), now);
  }

  /** Makes the current contract follow the given contract. Overwrites existing portfolio and oracles.
   * @param leaderPrism {Prism} See leaderPrism comment in FollowerManager.sol
   */
  function follow(PrismLibData.Data storage self, address leaderPrism, bool settleWithLeader) public {
    // auth
    if (msg.sender != self.accountLib.buyer) revert();
    if (self.state != PrismLibData.State.Open) revert();
    // ensure that leaderPrism is a prism
    if (!self.logger.prisms(leaderPrism)) revert();

    self.followerManagerLib.follow(leaderPrism, settleWithLeader, self.portfolioLib.principal);
    self.followStartValue = calculateValue(self);
  }

  /** Stop following the leader. */
  function unfollow(PrismLibData.Data storage self) public {
    if (msg.sender != self.accountLib.buyer) revert();

    withdrawFollowFee(self, calculateValue(self));
    self.followerManagerLib.unfollow(self.portfolioLib);
  }

  function lastUpdate(PrismLibData.Data storage self) internal constant returns(uint) {
    if (!self.followerManagerLib.hasLeader()) {
      return self.portfolioLib.lastUpdate();
    } else {
      uint[29] memory uints;
      (,,uints,) = IPrism(self.followerManagerLib.leaderPrism).data();
      return uints[28];
    }
  }

  /** Gets the value of the portfolio, or if following, the value of the leader portfolio. */
  function calculateValue(PrismLibData.Data storage self) internal constant returns(uint) {

    // if there is no leader, return the portfolio value
    if(!self.followerManagerLib.hasLeader()) {
      return self.portfolioLib.getValue();
    }
    // if there is a leader, return its value scaled by the principal ratio
    else {
      // get the leader value
      uint[29] memory uints;
      (,,uints,) = IPrism(self.followerManagerLib.leaderPrism).data();

      // if the leader is settled and settleWithLeader is true, use the leader's final value
      // otherwise use the normal leader value
      // Note: if leader is aborted we use normal leader value (leaderSettled() = false)
      // until unfollow()is called at which point the prism has its own portfolio
      uint leaderValue = uints[1];
      if (self.followerManagerLib.settleWithLeader) {
        if (self.followerManagerLib.leaderSettled() || leaderAborted(self)) {
          leaderValue = uints[2];
        }
      }

      // return the leader's value scaled by the principal ratio
      // i.e. leaderValue * principalRatio
      return multiplyPrincipalRatio(self, leaderValue);
    }
  }

  function numCoins(PrismLibData.Data storage self) public returns (uint) {

    // if no leader, return the number of coins in the portfolio
    if (!self.followerManagerLib.hasLeader()) {
      return self.portfolioLib.coinsHeld.length;
    }

    IPrism leaderPrism = IPrism(self.followerManagerLib.leaderPrism);
    return leaderPrism.numCoins();
    // otherwise return the number of coins of the leader
    // return IPrism(self.followerManagerLib.leaderPrism).numCoins();
  }

  /** Gets the amount of the given coin. Amounts of followers are defined by the leader. */
  function getCoinAmount(PrismLibData.Data storage self, bytes8 ticker) public returns (uint) {

    // if no leader, return the coin amount in the portfolio
    if (!self.followerManagerLib.hasLeader()) {
      uint coinAmount = self.portfolioLib.coins[ticker];
      return coinAmount;
    }

    // otherwise return the scaled coin amount of the leader
    // i.e leaderCoinAmount * principalRatio
    return multiplyPrincipalRatio(self, IPrism(self.followerManagerLib.leaderPrism).getCoinAmount(ticker));
  }

  function getCoinTicker(PrismLibData.Data storage self, uint i) public returns (bytes8) {

    // if no leader, return the coin ticker in the portfolio
    if (!self.followerManagerLib.hasLeader()) {
      return self.portfolioLib.coinsHeld[i];
    }

    // otherwise return the coin ticker of the leader
    return IPrism(self.followerManagerLib.leaderPrism).getCoinTicker(i);
  }
}
