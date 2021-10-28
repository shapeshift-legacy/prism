pragma solidity ^0.4.11;

import './Prism.sol';
import './ProxyFactory.sol';

contract PrismFactory {
  ProxyFactory public factory;
  Prism public target;
  address public proxy;

  function PrismFactory(address _factory, address _prism, address _proxy) public {
    require(_factory != 0x0);
    require(_prism != 0x0);
    require(_proxy != 0x0);

    factory = ProxyFactory(_factory);
    target = Prism(_prism);
    proxy = _proxy;
  }

  function create(address _buyer, address _seller, uint _principal, bytes8[] _tickers, uint[] _amounts, address _registrar, address _override, address _logger, uint _rebalanceFrequency, uint _followFee, uint _minFollowerPrincipal) public returns(address) {
    Prism prism = Prism(factory.createProxy(target, new bytes(0x0)));
    prism.initialize(_buyer, _seller, _principal, _tickers, _amounts, _registrar, _override, _logger, _rebalanceFrequency, _followFee, _minFollowerPrincipal);
    prism.initRelayFactory(address(factory), proxy);
    prism.transferOwner(msg.sender);
    return address(prism);
  }
}
