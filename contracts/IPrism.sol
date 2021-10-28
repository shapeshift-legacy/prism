pragma solidity ^0.4.11;

/** Define Prism interface in separate contract so libraries can reference Prisms without circular references. */
contract IPrism {
  enum State { Open, Accepted, Settled, Aborted }

  // Initialization
  function initRelayFactory(address factory, address target) public;

  // Ownership
  function transferOwner(address newOwner) public;
  function transferBuyer(address newBuyer) public;
  function transferSeller(address newSeller) public;
  function transferOverride(address newOverride) public;

  // Interaction
  function offer(uint[4] uints, uint[4] timespans, uint[8] fees) public payable;
  function depositToBuyer() public payable;
  function buyerWithdraw() public;
  function buyerSettleCommit() public;
  function buyerSettleConfirm() public;
  function sellerWithdraw() public;
  function ownerWithdraw() public;
  function proposeRebalance(uint _principal, uint _buyerCollateralRatio, uint _sellerCollateralRatio, bytes8[] tickers, uint[] amounts, address registrar) public payable;
  function approveRebalance(uint index) public payable;
  function sellerSettle() public;
  function abort(address to) public;
  function follow(address leaderPrism, bool settleWithLeader) public;
  function unfollow() public;

  // Accessors
  function data() public constant returns (uint, address[5], uint[29], bool[1]);
  function numCoins() public constant returns (uint);
  function getCoinAmount(bytes8 ticker) public constant returns (uint);
  function getCoinTicker(uint i) public constant returns (bytes8);
  function getRelays() public constant returns(address);
}
