pragma solidity ^0.4.19;

contract ProxyFactory {
    function createProxy(address _target, bytes _data) public returns (address proxyContract) {
        assembly {
            let contractCode := mload(0x40)                 // Find empty storage location using "free memory pointer"

            mstore(add(contractCode, 0x0e), _target) // Add target address, 14 bytes offset to later accomodate first part of the bytecode
            mstore(sub(contractCode, 0x06), 0x000000000000603a600c600039603a6000f33660008037611000600036600073)     // First part of the bytecode, shifted left 6 bytes, overwrites padding of target address
            mstore(add(contractCode, 0x2e), 0x5af43d6000803e80600081146053573d6000f35b3d6000fd0000000000000000)     // Final part of bytecode, 32 bytes after target

            proxyContract := create(0, contractCode, 0x46)    // total length 70 bytes in dec = 46 bytes in hex
            if iszero(extcodesize(proxyContract)) { revert(0,0) }

        // check if the _data.length > 0 and if it is forward it to the newly created contract
            if iszero(iszero(mload(_data))) {
                if call(gas, proxyContract, 0, add(_data, 0x20), mload(_data), 0, 0) { revert(0, 0) }
            }
        }

        ProxyDeployed(proxyContract, _target);
    }

    event ProxyDeployed(address proxyAddress, address targetAddress);
}