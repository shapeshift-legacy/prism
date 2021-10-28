pragma solidity ^0.4.11;

import './SafeMath.sol';

library DecimalMath {

  // decimal values (like percentages) are passed in as integers then divided by this to stimulate fixed precision
  uint constant internal fixedPrecision = 100000;

  function toFixed(uint num) public constant returns (uint) {
    return SafeMath.multiply(num, fixedPrecision);
  }

  function fromFixed(uint num) public constant returns (uint) {
    return num / fixedPrecision;
  }
}
