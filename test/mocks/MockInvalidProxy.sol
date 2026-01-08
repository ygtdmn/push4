// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/**
 * @title MockInvalidProxy
 * @notice Mock contract that does NOT implement IPUSH4Proxy's execute function
 * @dev Used for testing that PUSH4ProxyFactory rejects contracts without execute
 */
contract MockInvalidProxy {
    string public name;

    constructor(string memory _name) {
        name = _name;
    }

    // Intentionally missing execute(bytes4) function
}

