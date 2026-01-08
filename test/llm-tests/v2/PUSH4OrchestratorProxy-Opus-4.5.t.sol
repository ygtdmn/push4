// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";
import { PUSH4OrchestratorProxy } from "../../../src/PUSH4OrchestratorProxy.sol";
import { PUSH4RendererV2 } from "../../../src/PUSH4RendererV2.sol";
import { IPUSH4RendererV2 } from "../../../src/interface/IPUSH4RendererV2.sol";
import { IPUSH4Proxy } from "../../../src/interface/IPUSH4Proxy.sol";
import { PUSH4Core, IPUSH4Core } from "../../../src/PUSH4Core.sol";
import { PUSH4 } from "../../../src/PUSH4.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @notice Mock proxy for testing orchestrator
contract MockProxy is IPUSH4Proxy {
    string private _title;
    string private _description;
    Creator private _creator;
    bytes4 private _executeReturn;
    bool public shouldRevertOnCreator;

    constructor(string memory proxyTitle, string memory creatorName, address creatorWallet) {
        _title = proxyTitle;
        _description = "Mock proxy for testing";
        _creator = Creator({ name: creatorName, wallet: creatorWallet });
        _executeReturn = bytes4(0x12345678);
    }

    function execute(bytes4 selector) external view returns (bytes4) {
        // Simple transformation: XOR with fixed value
        return bytes4(uint32(selector) ^ uint32(_executeReturn));
    }

    function title() external view returns (string memory) {
        return _title;
    }

    function description() external view returns (string memory) {
        return _description;
    }

    function creator() external view returns (Creator memory) {
        if (shouldRevertOnCreator) {
            revert("Creator call failed");
        }
        return _creator;
    }

    function setExecuteReturn(bytes4 value) external {
        _executeReturn = value;
    }

    function setShouldRevertOnCreator(bool value) external {
        shouldRevertOnCreator = value;
    }
}

contract PUSH4OrchestratorProxyOpus45Test is Test {
    PUSH4OrchestratorProxy public orchestrator;
    PUSH4RendererV2 public rendererV2;
    PUSH4Core public push4Core;
    PUSH4 public push4;

    MockProxy public proxy1;
    MockProxy public proxy2;
    MockProxy public proxy3;

    address public owner = address(this);
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public collector = makeAddr("collector");
    address public creator1 = makeAddr("creator1");
    address public creator2 = makeAddr("creator2");
    address public creator3 = makeAddr("creator3");

    uint256 constant WIDTH = 15;
    uint256 constant HEIGHT = 25;
    uint256 constant PIXEL_SIZE = 20;
    uint256 constant BLOCK_INTERVAL = 100;

    string constant METADATA = '"name": "PUSH4 Orchestrator Test"';

    // Deterministic addresses
    address constant PUSH4_ADDRESS = 0x000000630bf663df3ff850DD34a28Fb7D4d52170;
    address constant PUSH4_CORE_ADDRESS = 0x00000063266aAAeDD489e4956153855626E44061;

    event ProxyRegistered(address indexed proxy, uint256 index);
    event ProxyUnregistered(address indexed proxy, uint256 index);
    event RendererUpdated(address indexed renderer);

    function setUp() public {
        // Deploy PUSH4 to deterministic address
        PUSH4 tempPush4 = new PUSH4();
        vm.etch(PUSH4_ADDRESS, address(tempPush4).code);
        push4 = PUSH4(PUSH4_ADDRESS);

        // Deploy PUSH4Core to deterministic address
        PUSH4Core tempCore = new PUSH4Core(address(push4), owner);
        vm.etch(PUSH4_CORE_ADDRESS, address(tempCore).code);
        for (uint256 i = 0; i < 20; i++) {
            bytes32 slot = bytes32(i);
            bytes32 value = vm.load(address(tempCore), slot);
            vm.store(PUSH4_CORE_ADDRESS, slot, value);
        }
        push4Core = PUSH4Core(PUSH4_CORE_ADDRESS);

        // Deploy RendererV2
        rendererV2 = new PUSH4RendererV2(WIDTH, HEIGHT, PIXEL_SIZE, push4Core, METADATA, BLOCK_INTERVAL, owner);

        // Mint token ID 0 to collector
        push4Core.mint(collector);

        // Deploy orchestrator
        orchestrator =
            new PUSH4OrchestratorProxy(owner, IPUSH4RendererV2(address(rendererV2)), IERC721(address(push4Core)));

        // Deploy mock proxies
        proxy1 = new MockProxy("Proxy 1", "Creator 1", creator1);
        proxy2 = new MockProxy("Proxy 2", "Creator 2", creator2);
        proxy3 = new MockProxy("Proxy 3", "Creator 3", creator3);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsOwner() public view {
        assertEq(orchestrator.owner(), owner);
    }

    function test_constructor_setsRenderer() public view {
        assertEq(address(orchestrator.renderer()), address(rendererV2));
    }

    function test_constructor_startsWithNoProxies() public view {
        assertEq(orchestrator.proxyCount(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                           REGISTER PROXY
    //////////////////////////////////////////////////////////////*/

    function test_registerProxy_addsProxy() public {
        orchestrator.registerProxy(proxy1);
        assertEq(orchestrator.proxyCount(), 1);
        assertTrue(orchestrator.isProxy(proxy1));
    }

    function test_registerProxy_emitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit ProxyRegistered(address(proxy1), 0);
        orchestrator.registerProxy(proxy1);
    }

    function test_registerProxy_canAddMultipleProxies() public {
        orchestrator.registerProxy(proxy1);
        orchestrator.registerProxy(proxy2);
        orchestrator.registerProxy(proxy3);

        assertEq(orchestrator.proxyCount(), 3);
        assertTrue(orchestrator.isProxy(proxy1));
        assertTrue(orchestrator.isProxy(proxy2));
        assertTrue(orchestrator.isProxy(proxy3));
    }

    function test_registerProxy_revertsWhenNotOwnerOrCollector() public {
        vm.prank(alice);
        vm.expectRevert(PUSH4OrchestratorProxy.NotOwnerOrCollector.selector);
        orchestrator.registerProxy(proxy1);
    }

    function test_registerProxy_revertsOnDuplicate() public {
        orchestrator.registerProxy(proxy1);
        vm.expectRevert(PUSH4OrchestratorProxy.ProxyAlreadyRegistered.selector);
        orchestrator.registerProxy(proxy1);
    }

    function test_registerProxy_revertsOnZeroAddress() public {
        vm.expectRevert(PUSH4OrchestratorProxy.InvalidProxy.selector);
        orchestrator.registerProxy(IPUSH4Proxy(address(0)));
    }

    /*//////////////////////////////////////////////////////////////
                          UNREGISTER PROXY
    //////////////////////////////////////////////////////////////*/

    function test_unregisterProxy_removesProxy() public {
        orchestrator.registerProxy(proxy1);
        orchestrator.registerProxy(proxy2);

        orchestrator.unregisterProxy(proxy1);

        assertEq(orchestrator.proxyCount(), 1);
        assertFalse(orchestrator.isProxy(proxy1));
        assertTrue(orchestrator.isProxy(proxy2));
    }

    function test_unregisterProxy_emitsEvent() public {
        orchestrator.registerProxy(proxy1);

        vm.expectEmit(true, true, true, true);
        emit ProxyUnregistered(address(proxy1), 0);
        orchestrator.unregisterProxy(proxy1);
    }

    function test_unregisterProxy_revertsWhenNotOwnerOrCollector() public {
        orchestrator.registerProxy(proxy1);

        vm.prank(alice);
        vm.expectRevert(PUSH4OrchestratorProxy.NotOwnerOrCollector.selector);
        orchestrator.unregisterProxy(proxy1);
    }

    function test_unregisterProxy_revertsWhenNotRegistered() public {
        vm.expectRevert(PUSH4OrchestratorProxy.ProxyNotFound.selector);
        orchestrator.unregisterProxy(proxy1);
    }

    function test_unregisterProxy_swapsWithLastElement() public {
        orchestrator.registerProxy(proxy1);
        orchestrator.registerProxy(proxy2);
        orchestrator.registerProxy(proxy3);

        // Remove proxy1 (index 0), proxy3 should be moved to index 0
        orchestrator.unregisterProxy(proxy1);

        assertEq(orchestrator.proxyCount(), 2);
        assertEq(address(orchestrator.getProxyAt(0)), address(proxy3));
        assertEq(address(orchestrator.getProxyAt(1)), address(proxy2));
    }

    /*//////////////////////////////////////////////////////////////
                            SET RENDERER
    //////////////////////////////////////////////////////////////*/

    function test_setRenderer_updatesRenderer() public {
        PUSH4RendererV2 newRenderer =
            new PUSH4RendererV2(WIDTH, HEIGHT, PIXEL_SIZE, push4Core, METADATA, BLOCK_INTERVAL, owner);
        orchestrator.setRenderer(newRenderer);
        assertEq(address(orchestrator.renderer()), address(newRenderer));
    }

    function test_setRenderer_emitsEvent() public {
        PUSH4RendererV2 newRenderer =
            new PUSH4RendererV2(WIDTH, HEIGHT, PIXEL_SIZE, push4Core, METADATA, BLOCK_INTERVAL, owner);
        vm.expectEmit(true, true, true, true);
        emit RendererUpdated(address(newRenderer));
        orchestrator.setRenderer(newRenderer);
    }

    function test_setRenderer_revertsWhenNotOwner() public {
        PUSH4RendererV2 newRenderer =
            new PUSH4RendererV2(WIDTH, HEIGHT, PIXEL_SIZE, push4Core, METADATA, BLOCK_INTERVAL, owner);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        orchestrator.setRenderer(newRenderer);
    }

    /*//////////////////////////////////////////////////////////////
                          GET CURRENT PROXY
    //////////////////////////////////////////////////////////////*/

    function test_getCurrentProxy_revertsWhenNoProxies() public {
        vm.expectRevert(PUSH4OrchestratorProxy.NoProxiesRegistered.selector);
        orchestrator.getCurrentProxy();
    }

    function test_getCurrentProxy_returnsSingleProxy() public {
        orchestrator.registerProxy(proxy1);
        assertEq(address(orchestrator.getCurrentProxy()), address(proxy1));
    }

    function test_getCurrentProxyIndex_revertsWhenNoProxies() public {
        vm.expectRevert(PUSH4OrchestratorProxy.NoProxiesRegistered.selector);
        orchestrator.getCurrentProxyIndex();
    }

    function test_getCurrentProxyIndex_rotatesBasedOnBlock() public {
        orchestrator.registerProxy(proxy1);
        orchestrator.registerProxy(proxy2);
        orchestrator.registerProxy(proxy3);

        // At block 0, index should be 0
        vm.roll(0);
        assertEq(orchestrator.getCurrentProxyIndex(), 0);

        // At block BLOCK_INTERVAL, index should be 1
        vm.roll(BLOCK_INTERVAL);
        assertEq(orchestrator.getCurrentProxyIndex(), 1);

        // At block BLOCK_INTERVAL * 2, index should be 2
        vm.roll(BLOCK_INTERVAL * 2);
        assertEq(orchestrator.getCurrentProxyIndex(), 2);

        // At block BLOCK_INTERVAL * 3, index should wrap to 0
        vm.roll(BLOCK_INTERVAL * 3);
        assertEq(orchestrator.getCurrentProxyIndex(), 0);
    }

    function test_getCurrentProxy_rotatesBasedOnBlock() public {
        orchestrator.registerProxy(proxy1);
        orchestrator.registerProxy(proxy2);

        vm.roll(0);
        assertEq(address(orchestrator.getCurrentProxy()), address(proxy1));

        vm.roll(BLOCK_INTERVAL);
        assertEq(address(orchestrator.getCurrentProxy()), address(proxy2));

        vm.roll(BLOCK_INTERVAL * 2);
        assertEq(address(orchestrator.getCurrentProxy()), address(proxy1));
    }

    /*//////////////////////////////////////////////////////////////
                        BLOCKS UNTIL NEXT PROXY
    //////////////////////////////////////////////////////////////*/

    function test_blocksUntilNextProxy_returnsZeroWhenNoProxies() public view {
        assertEq(orchestrator.blocksUntilNextProxy(), 0);
    }

    function test_blocksUntilNextProxy_calculatesCorrectly() public {
        orchestrator.registerProxy(proxy1);
        orchestrator.registerProxy(proxy2);

        // At block 0, should be BLOCK_INTERVAL blocks until next
        vm.roll(0);
        assertEq(orchestrator.blocksUntilNextProxy(), BLOCK_INTERVAL);

        // At block 50, should be 50 blocks until next
        vm.roll(50);
        assertEq(orchestrator.blocksUntilNextProxy(), 50);

        // At block 99, should be 1 block until next
        vm.roll(99);
        assertEq(orchestrator.blocksUntilNextProxy(), 1);

        // At block 100, should be BLOCK_INTERVAL blocks until next
        vm.roll(100);
        assertEq(orchestrator.blocksUntilNextProxy(), BLOCK_INTERVAL);
    }

    /*//////////////////////////////////////////////////////////////
                           PROXY AT BLOCK
    //////////////////////////////////////////////////////////////*/

    function test_proxyAtBlock_revertsWhenNoProxies() public {
        vm.expectRevert(PUSH4OrchestratorProxy.NoProxiesRegistered.selector);
        orchestrator.proxyAtBlock(0);
    }

    function test_proxyAtBlock_predictsFutureRotation() public {
        orchestrator.registerProxy(proxy1);
        orchestrator.registerProxy(proxy2);
        orchestrator.registerProxy(proxy3);

        assertEq(orchestrator.proxyAtBlock(0), 0);
        assertEq(orchestrator.proxyAtBlock(BLOCK_INTERVAL), 1);
        assertEq(orchestrator.proxyAtBlock(BLOCK_INTERVAL * 2), 2);
        assertEq(orchestrator.proxyAtBlock(BLOCK_INTERVAL * 3), 0);
        assertEq(orchestrator.proxyAtBlock(BLOCK_INTERVAL * 10), 1);
    }

    /*//////////////////////////////////////////////////////////////
                              IS CREATOR
    //////////////////////////////////////////////////////////////*/

    function test_isCreator_returnsFalseWhenNoProxies() public view {
        assertFalse(orchestrator.isCreator(creator1));
    }

    function test_isCreator_returnsTrueForRegisteredCreator() public {
        orchestrator.registerProxy(proxy1);
        assertTrue(orchestrator.isCreator(creator1));
    }

    function test_isCreator_checksAllProxies() public {
        orchestrator.registerProxy(proxy1);
        orchestrator.registerProxy(proxy2);
        orchestrator.registerProxy(proxy3);

        assertTrue(orchestrator.isCreator(creator1));
        assertTrue(orchestrator.isCreator(creator2));
        assertTrue(orchestrator.isCreator(creator3));
    }

    function test_isCreator_returnsFalseForNonCreator() public {
        orchestrator.registerProxy(proxy1);
        assertFalse(orchestrator.isCreator(alice));
    }

    function test_isCreator_handlesProxyFailuresGracefully() public {
        orchestrator.registerProxy(proxy1);
        orchestrator.registerProxy(proxy2);

        // Make proxy1 revert on creator() call
        proxy1.setShouldRevertOnCreator(true);

        // Should still find creator2 without reverting
        assertTrue(orchestrator.isCreator(creator2));

        // creator1's proxy reverts, so it shouldn't be found
        assertFalse(orchestrator.isCreator(creator1));
    }

    /*//////////////////////////////////////////////////////////////
                           GET CURRENT CREATOR
    //////////////////////////////////////////////////////////////*/

    function test_getCurrentCreator_returnsCurrentProxyCreator() public {
        orchestrator.registerProxy(proxy1);
        orchestrator.registerProxy(proxy2);

        vm.roll(0);
        IPUSH4Proxy.Creator memory currentCreator = orchestrator.getCurrentCreator();
        assertEq(currentCreator.wallet, creator1);

        vm.roll(BLOCK_INTERVAL);
        currentCreator = orchestrator.getCurrentCreator();
        assertEq(currentCreator.wallet, creator2);
    }

    /*//////////////////////////////////////////////////////////////
                           GET ALL CREATORS
    //////////////////////////////////////////////////////////////*/

    function test_getAllCreators_returnsAllCreators() public {
        orchestrator.registerProxy(proxy1);
        orchestrator.registerProxy(proxy2);
        orchestrator.registerProxy(proxy3);

        IPUSH4Proxy.Creator[] memory creators = orchestrator.getAllCreators();

        assertEq(creators.length, 3);
        assertEq(creators[0].wallet, creator1);
        assertEq(creators[1].wallet, creator2);
        assertEq(creators[2].wallet, creator3);
    }

    function test_getAllCreators_returnsEmptyWhenNoProxies() public view {
        IPUSH4Proxy.Creator[] memory creators = orchestrator.getAllCreators();
        assertEq(creators.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                               EXECUTE
    //////////////////////////////////////////////////////////////*/

    function test_execute_delegatesToCurrentProxy() public {
        orchestrator.registerProxy(proxy1);
        orchestrator.registerProxy(proxy2);

        bytes4 testSelector = bytes4(0xaabbccdd);

        vm.roll(0);
        bytes4 result1 = orchestrator.execute(testSelector);

        vm.roll(BLOCK_INTERVAL);
        bytes4 result2 = orchestrator.execute(testSelector);

        // Both proxies should return the same result since they use the same transformation
        // (XOR with 0x12345678)
        assertEq(result1, result2);
    }

    function test_execute_revertsWhenNoProxies() public {
        vm.expectRevert(PUSH4OrchestratorProxy.NoProxiesRegistered.selector);
        orchestrator.execute(bytes4(0x12345678));
    }

    /*//////////////////////////////////////////////////////////////
                              IS PROXY
    //////////////////////////////////////////////////////////////*/

    function test_isProxy_returnsTrueForRegisteredProxy() public {
        orchestrator.registerProxy(proxy1);
        assertTrue(orchestrator.isProxy(proxy1));
    }

    function test_isProxy_returnsFalseForUnregisteredProxy() public view {
        assertFalse(orchestrator.isProxy(proxy1));
    }

    function test_isProxy_returnsFalseAfterUnregister() public {
        orchestrator.registerProxy(proxy1);
        orchestrator.unregisterProxy(proxy1);
        assertFalse(orchestrator.isProxy(proxy1));
    }

    /*//////////////////////////////////////////////////////////////
                            GET PROXY AT
    //////////////////////////////////////////////////////////////*/

    function test_getProxyAt_returnsCorrectProxy() public {
        orchestrator.registerProxy(proxy1);
        orchestrator.registerProxy(proxy2);
        orchestrator.registerProxy(proxy3);

        assertEq(address(orchestrator.getProxyAt(0)), address(proxy1));
        assertEq(address(orchestrator.getProxyAt(1)), address(proxy2));
        assertEq(address(orchestrator.getProxyAt(2)), address(proxy3));
    }

    /*//////////////////////////////////////////////////////////////
                             PROXY COUNT
    //////////////////////////////////////////////////////////////*/

    function test_proxyCount_returnsCorrectCount() public {
        assertEq(orchestrator.proxyCount(), 0);

        orchestrator.registerProxy(proxy1);
        assertEq(orchestrator.proxyCount(), 1);

        orchestrator.registerProxy(proxy2);
        assertEq(orchestrator.proxyCount(), 2);

        orchestrator.unregisterProxy(proxy1);
        assertEq(orchestrator.proxyCount(), 1);
    }
}

