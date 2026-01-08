// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IPUSH4Proxy } from "./interface/IPUSH4Proxy.sol";
import { IPUSH4RendererV2 } from "./interface/IPUSH4RendererV2.sol";
import { IPUSH4OrchestratorProxy } from "./interface/IPUSH4OrchestratorProxy.sol";

/**
 * @title PUSH4OrchestratorProxy
 * @author Yigit Duman
 * @notice Manages multiple PUSH4 proxies and rotates between them based on block number
 */
contract PUSH4OrchestratorProxy is Ownable, IPUSH4OrchestratorProxy {
    IPUSH4Proxy[] public proxies;
    IPUSH4RendererV2 public renderer;
    IERC721 public push4Core;

    error ProxyAlreadyRegistered();
    error ProxyNotFound();
    error InvalidProxy();
    error NoProxiesRegistered();
    error NotOwnerOrCollector();

    event ProxyRegistered(address indexed proxy, uint256 index);
    event ProxyUnregistered(address indexed proxy, uint256 index);
    event RendererUpdated(address indexed renderer);

    modifier onlyOwnerOrCollector() {
        if (msg.sender != owner() && msg.sender != push4Core.ownerOf(0)) {
            revert NotOwnerOrCollector();
        }
        _;
    }

    constructor(address _owner, IPUSH4RendererV2 _renderer, IERC721 _push4Core) Ownable(_owner) {
        renderer = _renderer;
        push4Core = _push4Core;
    }

    function execute(bytes4 selector) external view returns (bytes4) {
        return getCurrentProxy().execute(selector);
    }

    function registerProxy(IPUSH4Proxy proxy) external onlyOwnerOrCollector {
        if (address(proxy) == address(0)) revert InvalidProxy();
        if (isProxy(proxy)) revert ProxyAlreadyRegistered();

        proxies.push(proxy);
        emit ProxyRegistered(address(proxy), proxies.length - 1);
    }

    function unregisterProxy(IPUSH4Proxy proxy) external onlyOwnerOrCollector {
        (uint256 index, bool found) = _findProxyIndex(proxy);
        if (!found) revert ProxyNotFound();

        // Swap with last element and pop to avoid shifting the array
        uint256 lastIndex = proxies.length - 1;
        if (index != lastIndex) {
            proxies[index] = proxies[lastIndex];
        }

        proxies.pop();
        emit ProxyUnregistered(address(proxy), index);
    }

    function setRenderer(IPUSH4RendererV2 _renderer) external onlyOwner {
        renderer = _renderer;
        emit RendererUpdated(address(renderer));
    }

    function isProxy(IPUSH4Proxy proxy) public view returns (bool) {
        for (uint256 i = 0; i < proxies.length; i++) {
            if (proxies[i] == proxy) {
                return true;
            }
        }
        return false;
    }

    /// @notice Checks if account is a creator in any registered proxy (fails silently on proxy errors)
    function isCreator(address account) public view returns (bool) {
        for (uint256 i = 0; i < proxies.length; i++) {
            try proxies[i].creator() returns (IPUSH4Proxy.Creator memory creatorInfo) {
                if (creatorInfo.wallet == account) {
                    return true;
                }
            } catch {
                continue;
            }
        }
        return false;
    }

    /// @notice Returns current proxy index based on block number rotation
    function getCurrentProxyIndex() public view returns (uint256) {
        if (proxies.length == 0) revert NoProxiesRegistered();

        // Divides blocks into intervals, then cycles through proxies
        return (block.number / renderer.blockInterval()) % proxies.length;
    }

    function getCurrentProxy() public view returns (IPUSH4Proxy) {
        if (proxies.length == 0) revert NoProxiesRegistered();

        return proxies[getCurrentProxyIndex()];
    }

    function getCurrentCreator() public view returns (IPUSH4Proxy.Creator memory) {
        return getCurrentProxy().creator();
    }

    /// @notice Returns remaining blocks until the next proxy rotation
    function blocksUntilNextProxy() external view returns (uint256) {
        if (proxies.length == 0) return 0;
        return renderer.blockInterval() - (block.number % renderer.blockInterval());
    }

    function proxyAtBlock(uint256 blockNumber) external view returns (uint256) {
        if (proxies.length == 0) revert NoProxiesRegistered();
        return (blockNumber / renderer.blockInterval()) % proxies.length;
    }

    function proxyCount() external view returns (uint256) {
        return proxies.length;
    }

    function getProxyAt(uint256 index) external view returns (IPUSH4Proxy) {
        return proxies[index];
    }

    function getAllCreators() external view returns (IPUSH4Proxy.Creator[] memory) {
        IPUSH4Proxy.Creator[] memory creators = new IPUSH4Proxy.Creator[](proxies.length);
        for (uint256 i = 0; i < proxies.length; i++) {
            creators[i] = proxies[i].creator();
        }
        return creators;
    }

    function _findProxyIndex(IPUSH4Proxy proxy) internal view returns (uint256 index, bool found) {
        for (uint256 i = 0; i < proxies.length; i++) {
            if (proxies[i] == proxy) {
                return (i, true);
            }
        }
        return (0, false);
    }

    function title() external pure override returns (string memory) {
        return "PUSH4 Orchestrator Proxy";
    }

    function description() external pure override returns (string memory) {
        return "Manages multiple PUSH4 proxies and rotates between them based on block number";
    }

    function owner() public view virtual override(Ownable, IPUSH4OrchestratorProxy) returns (address) {
        return super.owner();
    }

    function creator() external view override returns (Creator memory) {
        return Creator({ name: "Yigit Duman", wallet: owner() });
    }
}
