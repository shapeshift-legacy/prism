pragma solidity ^0.4.11;

import './MultiSig.sol';
import './SafeMath.sol';

/* A contract that manages ETH funds belonging to different addresses. Some functionality is public, some controlled by MultiSig. */
contract MultiAccount is MultiSig {

  mapping (address => uint) public accountBalances;

  /** Allow anyone to send funds. */
  function() payable {
    accountBalances[msg.sender] += msg.value;
  }

  /** Deposit funds into any account. */
  function deposit(address to) payable {
    accountBalances[to] += msg.value;
  }

  /** Transfers the given amount from the sender to the specified receiver. */
  function transfer(address from, address to, uint amount) public multisig {
    if(amount > accountBalances[from]) revert();

    accountBalances[from] = SafeMath.subtract(accountBalances[from], amount);
    accountBalances[to] = SafeMath.add(accountBalances[to], amount);
  }

  /** Transfers all available funds from the sender to the specified receiver. */
  function transferAll(address from, address to) public multisig {
    accountBalances[to] = SafeMath.add(accountBalances[to], accountBalances[from]);
    accountBalances[from] = 0; // must come after since its used in the calculation above
  }

  /** Withdraws from the balance of an account and sends them to the given address. */
  function withdrawFrom(address from, address to, uint amount) public multisig {
    if(amount > accountBalances[from]) revert();

    // funds subtracted first to prevent re-entry
    accountBalances[from] = SafeMath.subtract(accountBalances[from], amount);

    if(!to.call.value(amount)()) revert();
  }

  /** Withdraws from the balance of an account and sends them with a given function call. */
  function withdrawCall(address from, address to, uint amount, bytes4 methodId) public multisig {
    if(amount > accountBalances[from]) revert();

    // funds subtracted first to prevent re-entry
    accountBalances[from] = SafeMath.subtract(accountBalances[from], amount);

    if(!to.call.value(amount)(methodId)) revert();
  }
}
