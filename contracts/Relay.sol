pragma solidity ^0.4.4;

import './Proxy.sol';
import './ProxyFactory.sol';

/* The Relay contract serves as a base contract for any contract that wishes to expose methods through relay addresses.*/
library Relay {

  struct Data {
    // a mapping of methodId => owner => proxy address
    mapping (bytes4 => mapping(address => address)) relays;
    address factory;
    address target;
  }

  /** Adds a relay for the given method. */
  function addRelay(Data storage self, bytes4 methodId, address owner, bytes32 arg) returns(address) {
    Proxy proxy = Proxy(ProxyFactory(self.factory).createProxy(self.target, new bytes(0x0)));
    proxy.init(methodId, this, owner, arg);

    self.relays[methodId][owner] = address(proxy);
    return address(proxy);
  }

  /** Retrieves the dynamic contract address that can be sent a transaction to trigger the given method. */
  function getRelay(Data storage self, bytes4 methodId, address owner) constant returns (address) {
    return self.relays[methodId][owner];
  }

  /** Transfers a relay to a different owner. */
  function transferRelay(Data storage self, bytes4 methodId, address oldOwner, address newOwner) {
    Proxy proxy = Proxy(self.relays[methodId][oldOwner]);
    proxy.transferOwner(newOwner);
  }
}
