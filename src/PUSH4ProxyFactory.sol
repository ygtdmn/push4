// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { IPUSH4Proxy } from "./interface/IPUSH4Proxy.sol";

/**
 * @title PUSH4ProxyFactory
 * @author Yigit Duman
 * @notice Permissionless factory for deploying and tracking PUSH4 proxies
 * @dev Anyone can deploy or register proxies - this is an open registry unlike the curated orchestrator
 */
contract PUSH4ProxyFactory {
    IPUSH4Proxy[] public proxies;
    /// @dev Maps proxy address to index+1 in proxies array (0 = not registered)
    mapping(address => uint256) public proxyIndex;

    error ProxyAlreadyRegistered();
    error InvalidProxy();
    error NotAContract();
    error DeploymentFailed();
    error IndexOutOfBounds();

    event ProxyDeployed(address indexed proxy, address indexed deployer, uint256 index);
    event ProxyRegistered(address indexed proxy, address indexed registrant, uint256 index);

    /**
     * @notice Deploy a new proxy contract from bytecode
     * @param bytecode The creation bytecode of the proxy contract
     * @return proxy The address of the deployed proxy
     */
    function deploy(bytes memory bytecode) external returns (IPUSH4Proxy proxy) {
        if (bytecode.length == 0) revert InvalidProxy();

        address deployed;
        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        if (deployed == address(0)) revert DeploymentFailed();

        proxy = IPUSH4Proxy(deployed);

        // Verify the contract implements execute function
        try proxy.execute(bytes4(0)) returns (bytes4) {
            _registerProxy(proxy, msg.sender, true);
        } catch {
            revert InvalidProxy();
        }
    }

    /**
     * @notice Register an already deployed proxy contract
     * @param proxy The proxy contract to register
     */
    function register(IPUSH4Proxy proxy) external {
        if (address(proxy) == address(0)) revert InvalidProxy();
        if (address(proxy).code.length == 0) revert NotAContract();
        if (isRegistered(address(proxy))) revert ProxyAlreadyRegistered();

        // Verify the contract implements execute function
        try proxy.execute(bytes4(0)) returns (bytes4) {
            _registerProxy(proxy, msg.sender, false);
        } catch {
            revert InvalidProxy();
        }
    }

    function isRegistered(address proxy) public view returns (bool) {
        return proxyIndex[proxy] != 0;
    }

    function proxyCount() external view returns (uint256) {
        return proxies.length;
    }

    function getProxyAt(uint256 index) external view returns (IPUSH4Proxy) {
        if (index >= proxies.length) revert IndexOutOfBounds();
        return proxies[index];
    }

    function getProxies(uint256 offset, uint256 limit) external view returns (IPUSH4Proxy[] memory) {
        if (offset >= proxies.length) {
            return new IPUSH4Proxy[](0);
        }

        uint256 remaining = proxies.length - offset;
        uint256 count = remaining < limit ? remaining : limit;

        IPUSH4Proxy[] memory result = new IPUSH4Proxy[](count);
        unchecked {
            for (uint256 i = 0; i < count; ++i) {
                result[i] = proxies[offset + i];
            }
        }

        return result;
    }

    function _registerProxy(IPUSH4Proxy proxy, address deployer, bool isDeployment) internal {
        uint256 index = proxies.length;
        proxies.push(proxy);
        unchecked {
            proxyIndex[address(proxy)] = index + 1; // Store as 1-indexed
        }

        if (isDeployment) {
            emit ProxyDeployed(address(proxy), deployer, index);
        } else {
            emit ProxyRegistered(address(proxy), deployer, index);
        }
    }
}
