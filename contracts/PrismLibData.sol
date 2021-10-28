pragma solidity ^0.4.11;

import './Relay.sol';
import './RebalancerLib.sol';
import './FollowerManagerLib.sol';
import './PortfolioLib.sol';
import './PortfolioProposalLib.sol';
import './AccountLib.sol';
import './PrismLogger.sol';

library PrismLibData {

  /*************************************************
   * Enums
   *************************************************/

  enum State { Open, Accepted, Settled, Aborted }

  /*************************************************
   * Members
   *************************************************/

  struct Data {

    Relay.Data relay;
    RebalancerLib.Data rebalancerLib;
    FollowerManagerLib.Data followerManagerLib;
    PortfolioProposalLib.Data portfolioProposalLib;
    PortfolioLib.Data portfolioLib;
    AccountLib.Data accountLib;

    // time in seconds after an offer is made that the buyer can approve the proposal
    uint timespanOffer;

    // time in seconds from acceptance time when the buyer is allowed to settle
    uint timespanBeforeSettle;

    // time in seconds from buyer settle request to when prism can be settled and funds can be withdrawn
    uint timespanBeforeWithdraw;

    // time in seconds before the seller can liquidate the portfolio
    uint timespanDuration;

    // Open, Accepted, Settled, Aborted
    State state;

    // an override account with the ability to abort the contract
    address override;

    // a central logging contract with logRebalance and logStateChange methods
    PrismLogger logger;

    // the value of the prism when it started following another prism
    // this is used to determine the profit for follow fee upon settle/unfollow
    uint followStartValue;

    // mutex for locking Prisms in functions susceptible to re-entry
    bool locked;
  }
}
