pragma solidity ^0.4.11;

import "./IOracle.sol";

contract CerberusOracle is IOracle {

    uint constant precision = 1000000;

    struct SpotPrice {
        uint64 bid;
        // Not storing ask price for now
        //uint ask;
        uint64 updated;
    }
    
    event LogUpdate();
    
    address public owner;
    mapping(bytes8 => SpotPrice) prices;
    
    modifier ownerAccess() {
        if (msg.sender != owner) revert();
        _;
    }
    
    function CerberusOracle() public {
        owner = msg.sender;
    }

    function update(bytes8[] keys, uint[] bids, uint[] /*asks*/) public ownerAccess {
        uint8 i;
        for (i=0; i<keys.length; i++) {
            prices[keys[i]] = SpotPrice({
                bid: uint64(bids[i] / precision),
                updated: uint64(now)
            });
        }
        LogUpdate();
    }

    function transfer(address newOwner) public ownerAccess {
        owner = newOwner;
    }

    function get(bytes8 key) public view returns(uint /* bid */, uint /* ask */, uint64 /* timestamp */) {
        SpotPrice memory p = prices[key];
        if (p.bid == 0) revert();
        return (uint(p.bid) * precision, 0, p.updated);
    }

    function getArray(bytes8[] keys) public view returns(uint[3][]){
        // creates an array of fixed-size uint arrays
        uint[3][] memory values = new uint[3][](keys.length);
        for (uint i = 0; i < keys.length; i++) {
            var (bid, ask, updated) = CerberusOracle.get(keys[i]);
            values[i] = [bid, ask, updated];
        }
        // [[bid, ask, timestamp], [bid, ask, timestamp], ...]
        return values;
    }

    function kill() public ownerAccess {
        selfdestruct(owner);
    }
    
}