pragma solidity ^0.4.11;

import './SafeMath.sol';
import './Owned.sol';

/* A library that manages all funds for buyer, seller, and owner roles. */
library AccountLib {

  /*************************************************
   * Members
   *************************************************/

  struct Data {
    // the purchaser of the portfolio who can settle and rebalance at any time
    address buyer;

    // the seller who earns fees for putting up collateral
    address seller;

    // the smart contract owner who earns fees for infrastructure and market making
    address owner;

    // a mapping to keep track of all accountBalances
    mapping (address => uint) accountBalances;

    // the time that the prism became Accepted
    // this serves as the starting time for the pro-rated daily commission
    uint startTime;

    // the time that the prism became settled
    // this serves as the ending time for the pro-rated daily commission
    uint endTime;

    // the initial fee to the seller that can be immediately dailysionTransferred after the prism becomes Accepted
    uint initialCommission;

    // the amount of ETH that is paid daily to the seller. It can be withdrawn at a pro-rated rate at any time.
    // NOTE: This is given a fixed amount of ETH here, but is proposed to the Prism as a % of principal.
    uint dailyCommission;

    // keep track of how much the seller has dailysionTransferred so prevent repeat withdrawals during the Accepted state
    uint dailyCommissionTransferred;
  }

  /** Sets the buyer, ensuring that funds are transferred internally to the new buyer address. */
  function setBuyer(Data storage self, address _buyer) internal {
    // must use buyerFunds() and sellerFunds() instead of accountBalances directly so that dailyCommission is updated first
    transfer(self, self.buyer, _buyer, buyerFunds(self));
    self.buyer = _buyer;
  }

  /** Sets the seller, ensuring that funds are transferred internally to the new seller address. */
  function setSeller(Data storage self, address _seller) internal {
    // must use sellerFunds() instead of accountBalances directly so that dailyCommission is updated first
    transfer(self, self.seller, _seller, sellerFunds(self));
    self.seller = _seller;
  }

  /** Sets the owner, ensuring that funds are transferred internally to the new owner address. */
  function setOwner(Data storage self, address _owner) internal {
    // must use sellerFunds() instead of accountBalances directly so that dailyCommission is updated first
    transfer(self, self.owner, _owner, ownerFunds(self));
    self.owner = _owner;
  }

  /** Withdraws the given amout of buyer funds to the given address. */
  function buyerWithdraw(Data storage self, address to, uint amount) internal {
    withdrawFrom(self, self.buyer, to, amount);
  }

  /** Withdraw available seller funds. If Accepted, withdraws initial commission and a pro-rated amount of daily commission. If Settled, withdraws collateral. */
  function sellerWithdraw(Data storage self, address to, uint amount) internal {
    withdrawFrom(self, self.seller, to, amount);
  }

  /** Withdraws all fees to owner account */
  function ownerWithdraw(Data storage self, address to, uint amount) internal {
    withdrawFrom(self, self.owner, to, amount);
  }

  /** Withdraws from the balance of an account and sends them to the given address. */
  function withdrawFrom(Data storage self, address from, address to, uint amount) internal {
    if(amount > self.accountBalances[from]) revert();

    // funds subtracted first to prevent re-entry
    self.accountBalances[from] = SafeMath.subtract(self.accountBalances[from], amount);

    if(!to.call.value(amount)()) revert();
  }

  /** Withdraws the given amout of buyer funds to the given function call.Data storage self,  */
  function buyerWithdrawCall(Data storage self, address to, uint amount, bytes4 methodId) internal {
    withdrawCall(self, self.buyer, to, amount, methodId);
  }

  /** Withdraws from the balance of an account and sends them with a given function call. */
  function withdrawCall(Data storage self, address from, address to, uint amount, bytes4 methodId) internal {
    if(amount > self.accountBalances[from]) revert();

    // funds subtracted first to prevent re-entry
    self.accountBalances[from] = SafeMath.subtract(self.accountBalances[from], amount);

    if(!to.call.value(amount)(methodId)) revert();
  }

  /** Withdraw all funds directly. Does not adjust accountBalances.
   * WARNING: Only to be used as override.
   */
  function withdrawAll(Data storage /*self*/, address to) internal {
    if(!to.call.value(this.balance)()) revert();
  }

  /** Transfers the given amount from the sender to the specified receiver. */
  function transfer(Data storage self, address from, address to, uint amount) internal {
    if(amount > self.accountBalances[from]) revert();

    self.accountBalances[from] = SafeMath.subtract(self.accountBalances[from], amount);
    self.accountBalances[to] = SafeMath.add(self.accountBalances[to], amount);
  }

  /** Transfers all available funds from the sender to the specified receiver. */
  function transferAll(Data storage self, address from, address to) internal {
    self.accountBalances[to] = SafeMath.add(self.accountBalances[to], self.accountBalances[from]);
    self.accountBalances[from] = 0; // must come after since its used in the calculation above
  }

  /** Transfer the daily commission (pro-rated from startTime till now, or endTime if set) from the buyer to the seller. This is called automatically before any call to buyerFunds or sellerFunds to ensure that they use the most up-to-date balances. */
  // NOTE: This is safe for anyone to call, since it just transfers any outstanding daily commission to the seller and is idempotent (can be called multiple times without additional effect)
  function updateDailyCommission(Data storage self) internal {

    // do not start paying commission until the start time
    if(self.startTime == 0) return;

    // get the life of the contract in days (simulated fixed point)
    // use the current time if endTime is not set (i.e. Settled)
    uint currentEndTime = self.endTime != 0 ? self.endTime : now;
    uint lifespanSeconds = currentEndTime - self.startTime;

    // calculate the amount that the seller can withdraw at this time, based on
    // the amount of dailyCommission available minus the amount they previously withdrew
    // NOTE: Do divisions first to avoid overflow
    uint proratedCommission = SafeMath.subtract(SafeMath.multiply(self.dailyCommission / 1 days, lifespanSeconds), self.dailyCommissionTransferred);

    // if there are not enough buyer funds, transfer the remaining
    if (proratedCommission > self.accountBalances[self.buyer]) {
      proratedCommission = self.accountBalances[self.buyer];
    }

    // keep track of how much the seller withdraws so they can't withdraw it more than once
    self.dailyCommissionTransferred = SafeMath.add(self.dailyCommissionTransferred, proratedCommission);

    // finally, transfer the prorated fee from the buyer to the seller
    // NOTE: Assume that there will always be a prorated commission, so do not bother
    // saving gas by checking proratedCommission > 0
    transfer(self, self.buyer, self.seller, proratedCommission);
  }

  function depositTo(Data storage self, address to) internal {
    self.accountBalances[to] += msg.value;
  }

  function depositToBuyer(Data storage self) internal {
    self.accountBalances[self.buyer] += msg.value;
  }

  function depositToSeller(Data storage self) internal {
    self.accountBalances[self.seller] += msg.value;
  }

  /** Accept porfolio proposal */
  function acceptProposal(Data storage self, uint _startTime, uint _initialCommission, uint _dailyCommission) internal {
    self.startTime = _startTime;
    self.initialCommission = _initialCommission;
    self.dailyCommission = _dailyCommission;
  }

  /** Track when account settles */
  function setSettleEndTime(Data storage self, uint _endTime) internal {
    self.endTime = _endTime;
  }

  /** Retrieves the buyer's account balance. Always use this getter instead of accessing account.accountBalances directly so that dailyCommission can be updated first. */
  function buyerFunds(Data storage self) internal returns(uint) {

    // must transfer pro-rated daily commission from the buyer to the seller to have most up-to-date balance
    updateDailyCommission(self);

    return self.accountBalances[self.buyer];
  }

  /** Retrieves the seller's account balance. Always use this getter instead of accessing account.accountBalances directly so that dailyCommission can be updated first. */
  function sellerFunds(Data storage self) internal returns(uint) {

    // must transfer pro-rated daily commission from the self.buyer to the seller to have most up-to-date balance
    updateDailyCommission(self);

    return self.accountBalances[self.seller];
  }

  /** Retrieves the owner's account balance. Always use this getter instead of accessing account.accountBalances directly so that dailyCommission can be updated first. */
  function ownerFunds(Data storage self) internal returns(uint) {

    // must transfer pro-rated daily commission from the self.buyer to the owner to have most up-to-date balance
    updateDailyCommission(self);

    return self.accountBalances[self.owner];
  }
}
