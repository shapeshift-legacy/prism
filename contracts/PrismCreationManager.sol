pragma solidity ^0.4.11;

import './SafeMath.sol';
import './MultiAccount.sol';
import './Owned.sol';
import './DecimalMath.sol';

// prism component factories and interfaces
import './Prism.sol';

import './PrismFactory.sol';
import './PrismLogger.sol';

contract PrismCreationManager is Owned {

  enum RequestState { Null, Requested }

  modifier only(address account) { if (msg.sender != account) revert(); _; }

  // mutex
  bool private locked = false;
  modifier lock() {
    if(locked) revert();
    locked = true;
    _;
    locked = false;
  }

  // all the information that is needed to represent the creation of a prism
  struct CreationRequest {
    RequestState state;
    bytes32 prismDataHash;
  }

  mapping (address => CreationRequest) public requests;

  // seller to assign to new prisms
  address public seller;

  // fee paid to collector
  // not currently used
  uint public creationFee;

  // collector of required creation fee
  address public collector;

  MultiAccount public account;

  // prism component factories
  PrismFactory internal prismFactory;

  PrismLogger internal logger;

  function PrismCreationManager(address _logger, address _prismFactory, address _account, address _collector, address _seller, uint _creationFee) {
    Owned(this);
    account = MultiAccount(_account);
    prismFactory = PrismFactory(_prismFactory);
    collector = _collector;
    seller = _seller;
    creationFee = _creationFee;
    logger = PrismLogger(_logger);
  }

  /** When funds are sent to the manager, record the sender and check if a prism contract is ready to be created. */
  function() lock payable {

    if(msg.value == 0) {
      cancel();
    }
    else {
      // only accept funds from addresses that have requested a prism
      if(requests[msg.sender].state != RequestState.Requested) revert();

      account.deposit.value(msg.value)(msg.sender);
      // fire the FundsSent event
      // leave it up to an off-chain process to determine when the creation process should begin
      // (i.e. when the buyer has sent enough funds)
      logger.logFundsSent(msg.sender, requests[msg.sender].prismDataHash, msg.value);
    }
  }

  /** Adds a prism request with all the details of contract creation for the given buyer. */
  function add(address _buyer, bytes32 prismDataHash) only(owner) {
    requests[_buyer] = CreationRequest(RequestState.Requested, prismDataHash);
    logger.logRequest(_buyer, prismDataHash, now);
  }

  /** If the creation fee has been met, instantiates a new prism, makes an offer, and transfers it to the appropriate owner/buyer/seller.
    addresses[0] = buyer
    addresses[1] = seller
    addresses[2] = registrar
    addresses[3] = leader
    addresses[4] = override

    uints[0] = principal;
    uints[1] = initialCommission;
    uints[2] = dailyCommission;
    uints[3] = buyerCollateralRatio;
    uints[4] = followFee;
    uints[5] = minFollowerPrincipal;
    uints[6] = timespanDuration;
    uints[7] = timespanOffer;
    uints[8] = timespanBeforeSettle;
    uints[9] = sellerCollateralRatio;
    uints[10] = closingFeePercentBuyer;
    uints[11] = closingFeePercentSeller;
    uints[12] = closingFeeFixedBuyer;
    uints[13] = closingFeeFixedSeller;
    uints[14] = rebalanceFeePercentToSeller;
    uints[15] = rebalanceFeePercentToOwner;
    uints[16] = rebalanceFeeFixedToSeller;
    uints[17] = rebalanceFeeFixedToOwner;
    uints[18] = timespanBeforeWithdraw;
    uints[19] = rebalanceFrequency;
  */
  // NOTE: Must split into multiple functions so that they can be called across multiple blocks. The complete creation functionality requires more gas than will fit in a single block.
  function create(address[] addresses, bytes8[] tickers, uint[] amounts, uint[] uints, bool settleWithLeader) lock {

    CreationRequest request = requests[addresses[0]];

    if (request.state != RequestState.Requested) revert();

    // buyerFunds = principal + initialCommission + buyerCollateral
    if (account.accountBalances(addresses[0]) < SafeMath.add(uints[0], uints[1], DecimalMath.fromFixed(SafeMath.multiply(uints[3], uints[0])))) revert();

    // verify the creation parameters by comparing the hash
    verifyDataHash(addresses, tickers, amounts, uints, settleWithLeader);

    // create a prism with owner, buyer, and seller all set to this contract so that we can set it up properly before transferring ownership
    Prism prism = Prism(prismFactory.create(this, this, uints[0], tickers, amounts, addresses[2], addresses[4], logger, uints[19], uints[4], uints[5]));

//    prism.init();
    prism.offer([uints[1], uints[2], uints[3], uints[9]], [uints[7], uints[8], uints[6], uints[18]], [uints[10], uints[11], uints[12], uints[13], uints[14], uints[15], uints[16], uints[17]]);

    // must temporarily authorize PrismCreationManager in order to set up following
    if(addresses[3] != 0x0) {
      prism.follow(addresses[3], settleWithLeader);
    }

    prism.transferOwner(owner);
    prism.transferSeller(addresses[1]);
    prism.transferBuyer(addresses[0]);

    // deposit all buyer funds into prism
    // NOTE: this may include extra funds
    account.withdrawCall(addresses[0], prism, account.accountBalances(addresses[0]), Prism(0x0).depositToBuyer.selector);

    logCreation(addresses[0], request.prismDataHash, prism);

    // expire the request
    request.state = RequestState.Null;
  }

  // split into separate function to avoid stack depth limit.
  function logCreation(address buyer, bytes32 prismDataHash, Prism prism) private {
    // authorize the prism to log to the PrismLogger
    logger.registerPrism(prism);

    // get relay address to emit in Created event for server-side efficiency
    address settleRelay = prism.getRelays();

    logger.logCreated(buyer, prismDataHash, prism, settleRelay, now);
  }

  // split into separate function to avoid stack depth limit.
  /*
    addresses[0] = buyer
    addresses[1] = seller
    addresses[2] = coinOracle
    addresses[3] = leader
    addresses[4] = override

    uints[0] = principal;
    uints[1] = initialCommission;
    uints[2] = dailyCommission;
    uints[3] = buyerCollateralRatio;
    uints[4] = followFee;
    uints[5] = minFollowerPrincipal;
    uints[6] = timespanDuration;
    uints[7] = timespanOffer;
    uints[8] = timespanBeforeSettle;
    uints[9] = sellerCollateralRatio;
    uints[10] = closingFeePercentBuyer;
    uints[11] = closingFeePercentSeller;
    uints[12] = closingFeeFixedBuyer;
    uints[13] = closingFeeFixedSeller;
    uints[14] = rebalanceFeePercentToSeller;
    uints[15] = rebalanceFeePercentToOwner;
    uints[16] = rebalanceFeeFixedToSeller;
    uints[17] = rebalanceFeeFixedToOwner;
    uints[18] = timespanBeforeWithdraw;
  */
  function verifyDataHash(address[] addresses, bytes8[] tickers, uint[] amounts, uint[] uints, bool settleWithLeader) internal {
    if (requests[addresses[0]].prismDataHash != bytes32(sha3(
      addresses,
      tickers,
      amounts,
      uints,
      settleWithLeader
    ))) revert();
  }

  function getPrismDataHash(address buyer) returns(bytes32) {
    return requests[buyer].prismDataHash;
  }

  function getState(address buyer) returns(uint8) {
    return uint8(requests[buyer].state);
  }

  /** Allow sender to cancel a request and withdraw funds. */
  function cancel() {
    uint buyerBalance = account.accountBalances(msg.sender);
    requests[msg.sender].state = RequestState.Null;
    account.withdrawFrom(msg.sender, msg.sender, buyerBalance);
  }
}
