pragma solidity ^0.4.11;

import './PrismLib.sol';
import './PrismLib2.sol';
import './PrismLib3.sol';
import './PrismLogger.sol';
import './IPrism.sol';

// "is Owned" simulated in PrismLib to reduce bytecode
contract Prism is IPrism {

  /*************************************************
   * Data
   *************************************************/

  using PrismLib for PrismLibData.Data;
  using PrismLib2 for PrismLibData.Data;
  using PrismLib3 for PrismLibData.Data;
  using PortfolioLib for PortfolioLib.Data;
  using AccountLib for AccountLib.Data;
  PrismLibData.Data internal prismData;

  /*************************************************
   * Constructor
   *************************************************/
  bool initialized;

  modifier once { if (initialized) revert(); _; }

  function initialize(address _buyer, address _seller, uint _principal, bytes8[] tickers, uint[] amounts, address _registrar, address _override, address _logger, uint _rebalanceFrequency, uint _followFee, uint _minFollowerPrincipal) once {
    prismData.accountLib.owner = msg.sender;
    prismData.accountLib.buyer = _buyer;
    prismData.accountLib.seller = _seller;
    prismData.override = _override;
    prismData.logger = PrismLogger(_logger);

    prismData.rebalancerLib.rebalanceFrequency = _rebalanceFrequency;

    prismData.followerManagerLib.followFee = _followFee;
    prismData.followerManagerLib.minFollowerPrincipal = _minFollowerPrincipal;

    prismData.portfolioLib.principal = _principal;
    prismData.portfolioLib.initPortInternal(tickers, amounts, _registrar);

    initialized = true;
  }

  function initRelayFactory(address factory, address target) public {
    prismData.initRelayFactory(factory, target);
  }

  /*************************************************
   * Functions
   *************************************************/

  /** The fallback function is called when funds are sent directly to the contract address. Note: Keep gas usage minimal as all transfers that do not send enough gas will fail. */
  function() payable {
    prismData.fallback();
  }

  /** Returns all the relay addresses. */
  function getRelays() public constant returns(address) {
    return prismData.getRelays();
  }

  /** Allow the owner to transfer to another account. */
  function transferOwner(address newOwner) public {
    prismData.transferOwner(newOwner);
  }

  /** Allow the buyer to transfer to another account. */
  function transferBuyer(address newBuyer) public {
    prismData.transferBuyer(newBuyer);
  }

  /** Allow the seller to transfer to another account. */
  function transferSeller(address newSeller) public {
    prismData.transferSeller(newSeller);
  }

  /** Allow the override to transfer to another account. */
  function transferOverride(address newOverride) public {
    prismData.transferOverride(newOverride);
  }

  /** Make an offer as the seller. If the buyer accepts, the contract will enter an Accepted state. */
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
      timespans[3] = _timespanBeforeWithdraw

      fees[0] = _closingFeePercentBuyer
      fees[1] = _closingFeePercentSeller
      fees[2] = _closingFeeFixedBuyer
      fees[3] = _closingFeeFixedSeller
      fees[4] = _rebalanceFeePercentToSeller
      fees[5] = _rebalanceFeePercentToOwner
      fees[6] = _rebalanceFeeFixedToSeller
      fees[7] = _rebalanceFeeFixedToOwner
  */
  function offer(uint[4] uints, uint[4] timespans, uint[8] fees) public payable {
    prismData.offer(uints, timespans, fees);
  }

  /** Deposit funds directly to the buyer. Used in PrismCreationManager and leader payouts. */
  function depositToBuyer() public payable {
    prismData.accountLib.depositToBuyer();
  }

  /** Withdraws buyer funds to the given address depending on the prism state. */
  // NOTE: During Accepted, this will withdraw all funds beyond the principal, collateral, and one dailyCommission. This could include excess funds that were needed for follower fees. They can be re-added by sending ETH to the Prism.
  function buyerWithdraw() public {
    prismData.buyerWithdraw();
  }

  /** Attempts to settle the prism for the buyer. */
  function buyerSettleCommit() public {
    prismData.buyerSettleCommit();
  }

  /* Withdraws buyer funds after a time period, only to buyer's stored address. */
  function buyerSettleConfirm() public {
    prismData.buyerSettleConfirm();
  }

  /** Withdraw available seller funds. If Accepted, withdraws initial commission and a pro-rated amount of daily commission. If Settled, withdraws collateral. */
  function sellerWithdraw() public {
    prismData.sellerWithdraw();
  }

  /** Withdraw available owner funds. */
  function ownerWithdraw() public {
    prismData.ownerWithdraw();
  }

  function proposeRebalance(uint _principal, uint _buyerCollateralRatio, uint _sellerCollateralRatio, bytes8[] tickers, uint[] amounts, address registrar) public payable {
    uint[] memory uints = new uint[](3);
    uints[0] = _principal;
    uints[1] = _buyerCollateralRatio;
    uints[2] = _sellerCollateralRatio;
    prismData.proposeRebalance(uints, tickers, amounts, registrar);
  }

  function approveRebalance(uint index) public payable {
    prismData.approveRebalance(index);
  }

  /** Allows the self.seller to liquidate the contract if the value goes to 0. */
  // INVARIANT: prismProposal has been accepted because were are in an Accepted self.PrismLibData.state.
  function sellerSettle() public {
    prismData.sellerSettle();
  }

  /** An override that allows the contract to be aborted and funds drained. */
  function abort(address to) public {
    prismData.abort(to);
  }

  /** Makes the current contract follow the given contract. Overwrites existing portfolio and oracles.
   * @param leaderPrism {Prism}
   */
  function follow(address leaderPrism, bool settleWithLeader) public {
    prismData.follow(leaderPrism, settleWithLeader);
  }

  /** Stop following the leader. */
  function unfollow() public {
    prismData.unfollow();
  }

  /** A bundled getter for many member variables. This is done to reduce the bytecode size of having multiple individual getters. */
  function data() public constant returns(uint, address[5], uint[29], bool[1]) {
    return prismData.data();
  }

  function numCoins() public constant returns (uint) {
    return prismData.numCoins();
  }

  function getCoinAmount(bytes8 ticker) public constant returns (uint) {
    return prismData.getCoinAmount(ticker);
  }

  function getCoinTicker(uint i) public constant returns (bytes8) {
    return prismData.getCoinTicker(i);
  }
}
