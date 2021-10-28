pragma solidity ^0.4.11;

import "./PrismLibData.sol";
import './SafeMath.sol';
import './IPrism.sol';
import './CerberusOracle.sol';
import './Registrar.sol';
import './PortfolioProposalLib.sol';
import './DecimalMath.sol';

library PortfolioLib {

  using PortfolioProposalLib for PortfolioProposalLib.Data;

  /*************************************************
   * Structs
   *************************************************/

  struct Data {
    uint principal;

    // interpolation values
    uint preFinalTime;
    uint settleTime;
    uint preFinalValue;

    // the final value of the portfolio at settlement time
    uint finalValue;

    // ticker => amount
    mapping(bytes8 => uint) coins;
    bytes8[] coinsHeld;
    address registrar;

    // collateral required from the buyer and seller to accept the contract as a percentage of the value
    // also determines how much funds the buyer or seller can withdraw if overcollateralized
    // NOTE: stored as an integer that will be divided by fixedPrecision to simulate a fixed point number of a given precision
    uint buyerCollateralRatio;
    uint sellerCollateralRatio;

    // closing fees
    uint closingFeePercentBuyer;
    uint closingFeePercentSeller;
    uint closingFeeFixedBuyer;
    uint closingFeeFixedSeller;

    // rebalance fees
    uint rebalanceFeePercentToSeller;
    uint rebalanceFeePercentToOwner;
    uint rebalanceFeeFixedToSeller;
    uint rebalanceFeeFixedToOwner;
  }

  /*************************************************
   * Functions
   *************************************************/

  /** Copies the coin values of the portfolio. Also copies the registrar address. */
  function copyPortfolio(Data storage self, IPrism prism) public {
    // get prism data
    uint[29] memory uints;
    address[5] memory addresses;
    (,addresses,uints,) = prism.data();

    uint scale = DecimalMath.toFixed(self.principal) / uints[0]; // uints[0] = principal
    uint numOtherCoins = prism.numCoins();
    self.coinsHeld.length = 0;
    for (uint16 i=0; i<numOtherCoins; i++) {
      bytes8 ticker = prism.getCoinTicker(i);
      uint amount = prism.getCoinAmount(ticker);
      uint newAmount = DecimalMath.fromFixed(SafeMath.multiply(amount, scale));
      self.coinsHeld.push(ticker);
      self.coins[ticker] = newAmount;
    }

    self.registrar = addresses[2];
  }

  function initPortInternal(Data storage self, bytes8[] tickers, uint[] amounts, address registrarAddress) internal {
    if (tickers.length != amounts.length) revert();
    if (registrarAddress == 0x0) revert();

    self.coinsHeld.length = 0;
    for (uint16 i=0; i<tickers.length; i++) {
      self.coins[tickers[i]] = amounts[i];
    }
    self.coinsHeld = tickers;
    self.registrar = registrarAddress;
  }

  /** Returns the current market value of the given contract in ETH. */
  function getValue(Data storage self) public constant returns (uint) {
    uint portValue = 0;
    uint coinPrice;
    address oracleAddress = Registrar(self.registrar).registry('oracle');

    if (oracleAddress == 0x0) revert();

    for (uint16 i=0; i<self.coinsHeld.length; i++){
      uint coinAmount = self.coins[self.coinsHeld[i]];
      (coinPrice,) = CerberusOracle(oracleAddress).get(self.coinsHeld[i]);
      portValue = SafeMath.add(portValue, SafeMath.multiply(coinAmount, coinPrice) / 1 ether);
    }

    return portValue;
  }

  /** Returns the time the newest coin in the portfolio was last updated */
  function lastUpdate(Data storage self) public constant returns (uint) {
    uint coinTime;
    uint latestUpdate;
    address oracleAddress = Registrar(self.registrar).registry('oracle');
    for (uint16 i=0; i<self.coinsHeld.length; i++){
      (,,coinTime) = CerberusOracle(oracleAddress).get(self.coinsHeld[i]);
      if (latestUpdate < coinTime) latestUpdate = coinTime;
    }

    return latestUpdate;
  }

  /** Commit settle values. Can only happen once */
  function commitSettle(Data storage self, uint _settleTime, uint _preFinalTime, uint _preFinalValue) internal {
    if (self.settleTime > 0) revert();

    self.settleTime = _settleTime;
    self.preFinalTime = _preFinalTime;
    self.preFinalValue = _preFinalValue;
  }

  /** Sets final portfolio value */
  function setFinalValue(Data storage self, uint _finalValue) internal {
    self.finalValue = _finalValue;
  }

  /** Rebalance portfolio values */
  function rebalancePortfolio(Data storage self, uint _principal, uint _buyerCollateralRatio, uint _sellerCollateralRatio) internal {
    self.principal = _principal;
    self.buyerCollateralRatio = _buyerCollateralRatio;
    self.sellerCollateralRatio = _sellerCollateralRatio;
  }

  /** Transfers portfolio proposal values to the portfolio */
  function transferProposal(Data storage self, PortfolioProposalLib.Data storage portfolioProposalLib) internal {
    self.buyerCollateralRatio = portfolioProposalLib.buyerCollateralRatio;
    self.sellerCollateralRatio = portfolioProposalLib.sellerCollateralRatio;
    self.closingFeePercentBuyer = portfolioProposalLib.closingFeePercentBuyer;
    self.closingFeePercentSeller = portfolioProposalLib.closingFeePercentSeller;
    self.closingFeeFixedBuyer = portfolioProposalLib.closingFeeFixedBuyer;
    self.closingFeeFixedSeller = portfolioProposalLib.closingFeeFixedSeller;
    self.rebalanceFeePercentToSeller = portfolioProposalLib.rebalanceFeePercentToSeller;
    self.rebalanceFeePercentToOwner = portfolioProposalLib.rebalanceFeePercentToOwner;
    self.rebalanceFeeFixedToSeller = portfolioProposalLib.rebalanceFeeFixedToSeller;
    self.rebalanceFeeFixedToOwner = portfolioProposalLib.rebalanceFeeFixedToOwner;
  }

  /** Resets value of coin to zero */
  function deleteCoin(Data storage self, bytes8 _ticker) internal {
    delete self.coins[_ticker];
  }
}
