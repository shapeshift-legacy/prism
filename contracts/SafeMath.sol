pragma solidity ^0.4.11;

/** A library that provides mathematical operations that are safe from overflow. */
library SafeMath {

  function safeToAdd(uint a, uint b) constant returns (bool) {
    return a + b >= a;
  }

  function add(uint a, uint b) constant returns (uint) {
    if (!safeToAdd(a, b)) revert();
    return a + b;
  }

  function add(uint a, uint b, uint c) constant returns (uint) {
    if (!safeToAdd(a, b)) revert();
    return add(a + b, c);
  }

  function add(uint a, uint b, uint c, uint d) constant returns (uint) {
    if (!safeToAdd(a, b)) revert();
    return add(a + b, c, d);
  }

  function safeToSubtract(uint a, uint b) constant returns (bool) {
    return b <= a;
  }

  function subtract(uint a, uint b) constant returns (uint) {
    if (!safeToSubtract(a, b)) revert();
    return a - b;
  }

  function subtract(uint a, uint b, uint c) constant returns (uint) {
    if (!safeToSubtract(a, b)) revert();
    return subtract(a - b, c);
  }

  function subtract(uint a, uint b, uint c, uint d) constant returns (uint) {
    if (!safeToSubtract(a, b)) revert();
    return subtract(a - b, c, d);
  }

  function safeToMultiply(uint a, uint b) constant returns (bool) {
    return a == 0 || (a * b) / a == b;
  }

  function multiply(uint a, uint b) constant returns (uint) {
    if (!safeToMultiply(a, b)) revert();
    return a * b;
  }

  function absoluteDifference(uint a, uint b) constant returns (uint) {
    return safeToSubtract(a, b)
      ? a - b
      : b - a;
  }
}
