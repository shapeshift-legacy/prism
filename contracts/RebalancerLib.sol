pragma solidity ^0.4.11;

import './Relay.sol';
import './RebalanceProposal.sol';
import './PrismLibData.sol';
import './AccountLib.sol';
import './PrismLogger.sol';
import './PortfolioLib.sol';
import './SafeMath.sol';
import './CerberusOracle.sol';
import './Registrar.sol';
import './DecimalMath.sol';
import './IPrism.sol';

/** A module that handles rebalancing logic for Prisms */
library RebalancerLib {
  struct Data {

     // keep track of the last rebalance time so we can throttle rebalances
    uint timeLastRebalanced;

    // how frequently the buyer is allowed to rebalance (seconds)
    uint rebalanceFrequency;

    // the rebalance proposals
    RebalanceProposal proposal;

    // the rebalance proposal nonce prevents old rebalance proposals from getting uninentionally approved through the relay (since the relay transaction contains no data)
    uint nonce;
  }

  using PortfolioLib for PortfolioLib.Data;
  using AccountLib for AccountLib.Data;
  using Relay for Relay.Data;

  /*************************************************
   * Functions
   *************************************************/

  // NOTE: do not confuse with prismLib.proposeRebalance.
  /*
    uints[0] = _principal
    uints[1] = _buyerCollateralRatio
    uints[2] = _sellerCollateralRatio
  */
  function proposeRebalance(Data storage self, Relay.Data storage relay, PrismLogger logger, address buyer, address seller, uint[] uints, bytes8[] tickers, uint[] amounts, address registrar) internal {

    ++self.nonce;
    // make sure we are within the rebalance frequency limit
    if (now - self.timeLastRebalanced < self.rebalanceFrequency) revert();

    // Owner of RebalanceProposal will be this prism contract creating the proposal
    self.proposal = new RebalanceProposal(buyer, seller, uints[0], uints[1], uints[2], tickers, amounts, registrar);

    address relayAddress = relay.addRelay(IPrism(0x0).approveRebalance.selector, buyer, bytes32(self.nonce));

    logger.logRebalanceProposed(relayAddress, self.nonce, buyer, seller, amounts, tickers);
  }

  /** Attempts to rebalance the portfolio if the conditions are correct. */
  function tryRebalance(Data storage self, PortfolioLib.Data storage portfolioLib, AccountLib.Data storage accountLib, PrismLogger logger, uint nonce) internal {

    if(!verifyRebalance(self, accountLib, nonce)) return;

    /* Rebalance Fees == fixedFee + (percentageFee1 + percentageFee2 + ... + percentageFeeN)
        where percentageFee == ((((amountChanged * price) / 1 ether) * feePercentage) / fixedPrecision)
          and N is the number of coins in the rebalance proposal


      uints array necessary to prevent solidity `stack depth exceeded` error

        uints[0] = fixed rebalance fee to seller / total fees to seller
        uints[1] = fixed rebalance fee to owner / total fees to owner
        uints[2] = percentage rebalance fee to seller
        uints[3] = percentage rebalance fee to owner

        uints[4] = number of coins in proposal
        uints[5] = number of coins in current portfolio

        uints[6] = amount changed (newAmount - oldAmount)
        uints[7] = price of each coin in proposal
    */
    uint[] memory uints = new uint[](8);
    uints[0] = portfolioLib.rebalanceFeeFixedToSeller;
    uints[1] = portfolioLib.rebalanceFeeFixedToOwner;
    uints[2] = portfolioLib.rebalanceFeePercentToSeller;
    uints[3] = portfolioLib.rebalanceFeePercentToOwner;
    uints[4] = self.proposal.numCoins();
    uints[5] = portfolioLib.coinsHeld.length;

    // get tickers and amounts from proposal
    bytes8[] memory tickers = new bytes8[](uints[4]);
    uint[] memory amounts = new uint[](uints[4]);

    // calculate fee for new and changed coins
    for (uint i=0; i < uints[4]; i++) {
      // each new coin
      tickers[i] = self.proposal.tickers(i);
      amounts[i] = self.proposal.amounts(i);

      // old (current) coin
      uint oldCoinAmount = portfolioLib.coins[tickers[i]];

      uints[6] = SafeMath.absoluteDifference(amounts[i], oldCoinAmount);

      if (uints[6] > 0) {
        (uints[7],,) = CerberusOracle(Registrar(portfolioLib.registrar).registry('oracle')).get(tickers[i]);

        // fee calculation
        uints[0] = SafeMath.add(uints[0], calculateRebalanceFee(uints[6], uints[7], uints[2]));
        uints[1] = SafeMath.add(uints[1], calculateRebalanceFee(uints[6], uints[7], uints[3]));
      }

      // resets coin value to zero
      portfolioLib.deleteCoin(tickers[i]);
    }

    // calculate fee for removed coins
    for (i=0; i < uints[5]; i++) {
      // old (current) coin
      uints[6] = portfolioLib.coins[portfolioLib.coinsHeld[i]];

      // because we zero-out the existing amount for each coin in the Rebalance Proposal above,
      // we can safely assume that any coin left with an amount > 0 has been removed and
      // calculate fee based on existing amount.
      if (uints[6] > 0) {
        (uints[7],,) = CerberusOracle(Registrar(portfolioLib.registrar).registry('oracle')).get(portfolioLib.coinsHeld[i]);

        // fee calculation
        uints[0] = SafeMath.add(uints[0], calculateRebalanceFee(uints[6], uints[7], uints[2]));
        uints[1] = SafeMath.add(uints[1], calculateRebalanceFee(uints[6], uints[7], uints[3]));

        // resets old coin value to zero
        portfolioLib.deleteCoin(portfolioLib.coinsHeld[i]);
      }
    }

    // transfer owner fees first
    if (uints[1] > 0) {
      accountLib.transfer(accountLib.buyer, accountLib.owner, uints[1]);
    }

    if (uints[0] > 0) {
      accountLib.transfer(accountLib.buyer, accountLib.seller, uints[0]);
    }

    portfolioLib.rebalancePortfolio(self.proposal.principal(), self.proposal.buyerCollateralRatio(), self.proposal.sellerCollateralRatio());
    portfolioLib.initPortInternal(tickers, amounts, self.proposal.registrar());

    self.timeLastRebalanced = now;

    logger.logRebalance(amounts, tickers, uints[0], uints[1], nonce);
  }

  /** Calculate rebalance fees */
  function calculateRebalanceFee(uint amountChanged, uint coinPrice, uint percentageFee) internal returns (uint) {
    return DecimalMath.fromFixed(SafeMath.multiply((SafeMath.multiply(amountChanged, coinPrice) / 1 ether), percentageFee));
  }

  /** Approve the rebalance rebalancerLib.proposal as buyer or seller. */
  function approveAsMember(Data storage self, address member) public {
    self.proposal.approveAsMember(member);
  }

  /** Returns true if the conditions are met to perform a rebalance:
   - proposal must be Approved
   - seller must have paid collateral
   - buyer must have paid the principal, collateral, and initialCommission
  */
  function verifyRebalance(Data storage self, AccountLib.Data storage accountLib, uint nonce) constant returns(bool) {

    if (self.nonce != nonce) return false;

    // NOTE: Must divide by fixedPrecision first to avoid multiplication overflow
    uint buyerCollateral = SafeMath.multiply(DecimalMath.fromFixed(self.proposal.principal()), self.proposal.buyerCollateralRatio());
    uint sellerCollateral = SafeMath.multiply(DecimalMath.fromFixed(self.proposal.principal()), self.proposal.sellerCollateralRatio());

    if (!self.proposal.isApproved()) return false;
    if (accountLib.sellerFunds() < sellerCollateral) return false;

    // take into account that the some of the daily commission has already been transferred to the seller
    // i.e. assert(buyerFunds() >= principal + buyerCollateral - dailyCommissionTransferred)
    if (accountLib.buyerFunds() < SafeMath.subtract(SafeMath.add(self.proposal.principal(), buyerCollateral), accountLib.dailyCommissionTransferred)) return false;

    return true;
  }
 }
