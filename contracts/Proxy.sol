pragma solidity ^0.4.11;

/** The Proxy contract represents a single method on a host contract. It stores the address of the host contract and the method id of the method so that it can invoke the method when a user sends funds to this contract's address. Note: This version is permission-less. Most use cases would require an authorized owner contract. */
contract Proxy {

    /* The address of the relay owner (who has permission to trigger it). */
    address owner;

    /* The address of the host contract. */
    address host;

    /* The methodId of the host contract method. This is equivalent to bytes4(sha3(methodName)) where the method name includes the parentheses as if you were calling the function. */
    bytes4 methodId;

    /** Arbitrary data to send as first argument to function. */
    bytes32 arg;

    bool initialized;

    modifier once { if (initialized) revert(); _; }

    function init(bytes4 _methodId, address _host, address _owner, bytes32 _arg) once {
        host = _host;
        owner = _owner;
        methodId = _methodId;
        arg = _arg;
    }

    modifier onlyOwner { if (msg.sender != owner) revert(); _; }

    function transferOwner(address newOwner) onlyOwner {
        owner = newOwner;
    }

    function() payable onlyOwner {
        // if host call throws, throw this transaction as well
        if(!host.call.value(msg.value)(methodId, arg)) throw;
    }
}
