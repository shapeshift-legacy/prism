pragma solidity ^0.4.11;

import './Owned.sol';

/** A contract that provides central logging capabilities for prisms. */
contract PrismLogger is Owned {

  // addresses (PrismCreationManagers) which are authorized to register prisms
  mapping (address => bool) public creationManagers;

  // addresses (Prisms) which are authorized to log messages
  mapping (address => bool) public prisms;

  // admin events
  event CreationManagerAuthorized(address creationManager);
  event PrismRegistered(address creationManager, address prism);

  // prism events
  event SettleCommit(address indexed prism, uint timespanBeforeWithdraw);
  event Rebalanced(address indexed prism, uint[] amounts, bytes8[] tickers, uint feeToSeller, uint feeToOwner, uint nonce);
  event StateChanged(address indexed prism, uint indexed state, uint time);
  event RebalanceProposed(address indexed prism, address relay, uint nonce, address buyer, address seller, uint[] amounts, bytes8[] tickers);

  // creation manager events
  event Request(address indexed creationManager, address indexed buyer, bytes32 prismDataHash, uint time);
  event FundsSent(address indexed creationManager, address indexed buyer, bytes32 prismDataHash, uint amount);
  event Created(address indexed creationManager, address indexed buyer, bytes32 prismDataHash, address prismAddress, address settleRelay, uint time);

  // modifiers
  modifier onlyOwner() { if (msg.sender != owner) revert(); _; }
  modifier onlyCreationManager() { if (!creationManagers[msg.sender]) revert(); _; }
  modifier onlyPrism() { if (!prisms[msg.sender]) revert(); _; }

  /* Authorizes a given address (PrismCreationManager) to be able to register prisms. */
  function authorizeCreationManager(address creationManager) onlyOwner {
    creationManagers[creationManager] = true;
    CreationManagerAuthorized(creationManager);
  }

  /** Registers a prism so that it may log messages. */
  function registerPrism(address prism) onlyCreationManager {
    prisms[prism] = true;
    PrismRegistered(msg.sender, prism);
  }

  /** prism event logging functions */
  function logRebalanceProposed(address relay, uint nonce, address buyer, address seller, uint[] amounts, bytes8[] tickers) onlyPrism {
    RebalanceProposed(msg.sender, relay, nonce, buyer, seller, amounts, tickers);
  }

  function logRebalance(uint[] amounts, bytes8[] tickers, uint feeToSeller, uint feeToOwner, uint nonce) onlyPrism {
    Rebalanced(msg.sender, amounts, tickers, feeToSeller, feeToOwner, nonce);
  }

  function logStateChange(uint state, uint time) onlyPrism {
    StateChanged(msg.sender, state, time);
  }

  function logSettleCommit(uint timespan) onlyPrism {
    SettleCommit(msg.sender, timespan);
  }

  /** creation manager event logging functions */
  function logRequest(address buyer, bytes32 prismDataHash, uint time) onlyCreationManager {
    Request(msg.sender, buyer, prismDataHash, time);
  }

  function logFundsSent(address buyer, bytes32 prismDataHash, uint amount) onlyCreationManager {
    FundsSent(msg.sender, buyer, prismDataHash, amount);
  }

  function logCreated(address buyer, bytes32 prismDataHash, address prismAddress, address settleRelay, uint time) onlyCreationManager {
    Created(msg.sender, buyer, prismDataHash, prismAddress, settleRelay, time);
  }
}
