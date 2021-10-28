pragma solidity ^0.4.11;

import "./PrismLibData.sol";
import "./IPrism.sol";

// // define an interface for a FollowerManager since we cannot import FollowerManager directly (circular)
// contract IFollowerManager {
//   function portfolio() public constant returns(Portfolio);
//   function minFollowerPrincipal() public constant returns(uint);
//   function leader() public constant returns(IFollowerManager);
// }

library FollowerManagerLib {

  /*************************************************
   * Structs
   *************************************************/

  struct Data {
    // the percentage of the follower profit to be paid to the leader at settle/unfollow
    // NOTE: stored as an integer that will be divided by fixedPrecision to simulate a fixed point number of a given precision. e.g.
    uint followFee;

    // the minimum amount of principal needed by the follower
    uint minFollowerPrincipal;

    // if true, the follower will be automatically settled when the leader settles
    bool settleWithLeader;

    // Currently this is needed for leaderSettle's authorization, since it is called by
    // the leader Prism not the leader FollowerManager contract.
    address leaderPrism;
  }

  /*************************************************
   * Internal Helper Functions
   *************************************************/

  /** Returns true if the prism has a leader. */
  function hasLeader(Data storage self) internal constant returns (bool) {
    return address(self.leaderPrism) != 0x0;
  }

  /** Returns true if the leader exists and has settled. */
  function leaderSettled(Data storage self) internal constant returns (bool) {
    if (!hasLeader(self)) {
      return false;
    }

    uint leaderState;
    (leaderState,,,) = IPrism(self.leaderPrism).data();

    return IPrism.State(leaderState) == IPrism.State.Settled;
  }

  /*************************************************
   * Functions
   *************************************************/

  /** Makes the current contract follow the given FollowerManager. Overwrites existing self.portfolio and oracles.
  */
  function follow(Data storage self, address _leaderPrism, bool _settleWithLeader, uint _principal) public {
    // must not be following already
    if (address(self.leaderPrism) != 0) revert();

    // do verification of all follow conditions
    if(!verifyFollow(_leaderPrism, _principal)) revert();

    self.leaderPrism = _leaderPrism;
    self.settleWithLeader = _settleWithLeader;
  }

  /** Stops following another contract. Copies leader self.portfolio so it can run solo. */
  function unfollow(Data storage self, PortfolioLib.Data storage portfolioLib) public {
    // must be following
    if (address(self.leaderPrism) == 0) revert();

    // cannot unfollow if self.settleWithLeader && leaderState == settled
    // Note: if leaderState == aborted this prism can unfollow
    if (self.settleWithLeader && leaderSettled(self)) revert();

    PortfolioLib.copyPortfolio(portfolioLib, IPrism(self.leaderPrism));

    self.leaderPrism = 0x0;
  }

  /** Check that the conditions are correct for following the assigned leader. Abstracted into a separate function so that it can be called at follow-time and at accept-time. */
  function verifyFollow(address _leader, uint principal) internal constant returns(bool) {

    // must be a valid address for the new leader
    if (_leader == 0x0) {
      return false;
    }

    // get leader data
    address[5] memory addresses;
    uint[29] memory uints;
    uint leaderState;
    (leaderState,addresses,uints,) = IPrism(_leader).data();

    return this.balance == 0 && // don't allow following if one party has already funded the prism
      IPrism.State(leaderState) == IPrism.State.Accepted && // Prism must be in accepted state
      principal >= uints[14] && // follower must have minimum principal (uints[14] = minFollowerPrincipal)
      addresses[4] == 0x0;           // leader must not be following (addresses[4] = leader)
  }
}
