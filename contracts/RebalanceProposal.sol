pragma solidity ^0.4.11;

import './BuyerSellerProposal.sol';

/** A Proposal for rebalances requiring approval by a buyer and seller. */
contract RebalanceProposal is BuyerSellerProposal {

  // initial value of portfolio
  uint public principal;

  // collateral required from the buyer and seller to accept the contract as a percentage of the value
  // also determines how much funds the buyer or seller can withdraw if overcollateralized
  // NOTE: stored as an integer that will be divided by fixedPrecision to simulate a fixed point number of a given precision
  uint public buyerCollateralRatio;
  uint public sellerCollateralRatio;

  bytes8[] public tickers;
  uint[] public amounts;
  address public registrar;

  function RebalanceProposal(address _buyer, address _seller, uint _principal, uint _buyerCollateralRatio, uint _sellerCollateralRatio, bytes8[] _tickers, uint[] _amounts, address _registrar) BuyerSellerProposal(_buyer, _seller) {
    principal = _principal;
    buyerCollateralRatio = _buyerCollateralRatio;
    sellerCollateralRatio = _sellerCollateralRatio;
    tickers = _tickers;
    amounts = _amounts;
    registrar = _registrar;
  }

  function numCoins() public constant returns(uint) {
    return tickers.length;
  }
}
