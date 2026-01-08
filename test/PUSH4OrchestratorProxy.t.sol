// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";
import { PUSH4OrchestratorProxy } from "../src/PUSH4OrchestratorProxy.sol";
import { PUSH4RendererV2 } from "../src/PUSH4RendererV2.sol";
import { PUSH4Core } from "../src/PUSH4Core.sol";
import { PUSH4 } from "../src/PUSH4.sol";
import { IPUSH4Proxy } from "../src/interface/IPUSH4Proxy.sol";
import { IPUSH4RendererV2 } from "../src/interface/IPUSH4RendererV2.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { MockPUSH4Proxy } from "./mocks/MockPUSH4Proxy.sol";

contract PUSH4OrchestratorProxyTest is Test {
    // Deterministic addresses
    address constant PUSH4_ADDRESS = 0x000000630bf663df3ff850DD34a28Fb7D4d52170;
    address constant PUSH4_CORE_ADDRESS = 0x00000063266aAAeDD489e4956153855626E44061;

    PUSH4 public push4;
    PUSH4Core public push4Core;
    PUSH4RendererV2 public rendererV2;
    PUSH4OrchestratorProxy public orchestrator;

    MockPUSH4Proxy public proxy1;
    MockPUSH4Proxy public proxy2;
    MockPUSH4Proxy public proxy3;

    address public owner = address(this);
    address public alice = makeAddr("alice");
    address public collector = makeAddr("collector");
    address public creator1 = makeAddr("creator1");
    address public creator2 = makeAddr("creator2");
    address public creator3 = makeAddr("creator3");

    uint256 public constant BLOCK_INTERVAL = 100;

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
        rendererV2 = new PUSH4RendererV2(15, 25, 20, push4Core, "test metadata", BLOCK_INTERVAL, owner);
        push4Core.setRenderer(rendererV2);

        // Mint token ID 0 to collector
        push4Core.mint(collector);

        // Deploy Orchestrator
        orchestrator =
            new PUSH4OrchestratorProxy(owner, IPUSH4RendererV2(address(rendererV2)), IERC721(address(push4Core)));

        // Deploy mock proxies with different creators
        proxy1 = new MockPUSH4Proxy("Proxy 1", "First proxy", "Creator 1", creator1);
        proxy2 = new MockPUSH4Proxy("Proxy 2", "Second proxy", "Creator 2", creator2);
        proxy3 = new MockPUSH4Proxy("Proxy 3", "Third proxy", "Creator 3", creator3);
    }

    /*//////////////////////////////////////////////////////////////
                          CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsOwner() public view {
        assertEq(orchestrator.owner(), owner);
    }

    function test_constructor_setsRenderer() public view {
        assertEq(address(orchestrator.renderer()), address(rendererV2));
    }

    function test_constructor_setsPush4Core() public view {
        assertEq(address(orchestrator.push4Core()), address(push4Core));
    }

    /*//////////////////////////////////////////////////////////////
                       REGISTERPROXY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_registerProxy_addsProxy() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));

        assertEq(orchestrator.proxyCount(), 1);
        assertEq(address(orchestrator.getProxyAt(0)), address(proxy1));
    }

    function test_registerProxy_addsMultipleProxies() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy3)));

        assertEq(orchestrator.proxyCount(), 3);
        assertEq(address(orchestrator.getProxyAt(0)), address(proxy1));
        assertEq(address(orchestrator.getProxyAt(1)), address(proxy2));
        assertEq(address(orchestrator.getProxyAt(2)), address(proxy3));
    }

    function test_registerProxy_emitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit PUSH4OrchestratorProxy.ProxyRegistered(address(proxy1), 0);
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
    }

    function test_registerProxy_emitsEventWithCorrectIndex() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));

        vm.expectEmit(true, false, false, true);
        emit PUSH4OrchestratorProxy.ProxyRegistered(address(proxy2), 1);
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));
    }

    function test_registerProxy_revertsWhenNotOwnerOrCollector() public {
        vm.prank(alice);
        vm.expectRevert(PUSH4OrchestratorProxy.NotOwnerOrCollector.selector);
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
    }

    function test_registerProxy_revertsWithZeroAddress() public {
        vm.expectRevert(PUSH4OrchestratorProxy.InvalidProxy.selector);
        orchestrator.registerProxy(IPUSH4Proxy(address(0)));
    }

    function test_registerProxy_revertsWhenAlreadyRegistered() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));

        vm.expectRevert(PUSH4OrchestratorProxy.ProxyAlreadyRegistered.selector);
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
    }

    function test_registerProxy_worksForCollector() public {
        vm.prank(collector);
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));

        assertEq(orchestrator.proxyCount(), 1);
        assertEq(address(orchestrator.getProxyAt(0)), address(proxy1));
    }

    function test_registerProxy_worksForBothOwnerAndCollector() public {
        // Owner registers first proxy
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        assertEq(orchestrator.proxyCount(), 1);

        // Collector registers second proxy
        vm.prank(collector);
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));
        assertEq(orchestrator.proxyCount(), 2);
    }

    /*//////////////////////////////////////////////////////////////
                      UNREGISTERPROXY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_unregisterProxy_removesProxy() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.unregisterProxy(IPUSH4Proxy(address(proxy1)));

        assertEq(orchestrator.proxyCount(), 0);
    }

    function test_unregisterProxy_removesMiddleProxy() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy3)));

        orchestrator.unregisterProxy(IPUSH4Proxy(address(proxy2)));

        assertEq(orchestrator.proxyCount(), 2);
        // Last element (proxy3) should be swapped to index 1
        assertEq(address(orchestrator.getProxyAt(0)), address(proxy1));
        assertEq(address(orchestrator.getProxyAt(1)), address(proxy3));
    }

    function test_unregisterProxy_removesLastProxy() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));

        orchestrator.unregisterProxy(IPUSH4Proxy(address(proxy2)));

        assertEq(orchestrator.proxyCount(), 1);
        assertEq(address(orchestrator.getProxyAt(0)), address(proxy1));
    }

    function test_unregisterProxy_emitsEvent() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));

        vm.expectEmit(true, false, false, true);
        emit PUSH4OrchestratorProxy.ProxyUnregistered(address(proxy1), 0);
        orchestrator.unregisterProxy(IPUSH4Proxy(address(proxy1)));
    }

    function test_unregisterProxy_revertsWhenNotOwnerOrCollector() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));

        vm.prank(alice);
        vm.expectRevert(PUSH4OrchestratorProxy.NotOwnerOrCollector.selector);
        orchestrator.unregisterProxy(IPUSH4Proxy(address(proxy1)));
    }

    function test_unregisterProxy_revertsWhenProxyNotFound() public {
        vm.expectRevert(PUSH4OrchestratorProxy.ProxyNotFound.selector);
        orchestrator.unregisterProxy(IPUSH4Proxy(address(proxy1)));
    }

    function test_unregisterProxy_revertsWhenProxyNotRegistered() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));

        vm.expectRevert(PUSH4OrchestratorProxy.ProxyNotFound.selector);
        orchestrator.unregisterProxy(IPUSH4Proxy(address(proxy2)));
    }

    function test_unregisterProxy_worksForCollector() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));

        vm.prank(collector);
        orchestrator.unregisterProxy(IPUSH4Proxy(address(proxy1)));

        assertEq(orchestrator.proxyCount(), 0);
    }

    function test_unregisterProxy_worksForBothOwnerAndCollector() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));

        // Collector unregisters first proxy
        vm.prank(collector);
        orchestrator.unregisterProxy(IPUSH4Proxy(address(proxy1)));
        assertEq(orchestrator.proxyCount(), 1);

        // Owner unregisters second proxy
        orchestrator.unregisterProxy(IPUSH4Proxy(address(proxy2)));
        assertEq(orchestrator.proxyCount(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        SETRENDERER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setRenderer_updatesRenderer() public {
        PUSH4RendererV2 newRenderer = new PUSH4RendererV2(15, 25, 20, push4Core, "new metadata", 50, owner);

        orchestrator.setRenderer(IPUSH4RendererV2(address(newRenderer)));

        assertEq(address(orchestrator.renderer()), address(newRenderer));
    }

    function test_setRenderer_emitsEvent() public {
        PUSH4RendererV2 newRenderer = new PUSH4RendererV2(15, 25, 20, push4Core, "new metadata", 50, owner);

        vm.expectEmit(true, false, false, false);
        emit PUSH4OrchestratorProxy.RendererUpdated(address(newRenderer));
        orchestrator.setRenderer(IPUSH4RendererV2(address(newRenderer)));
    }

    function test_setRenderer_revertsWhenNotOwner() public {
        PUSH4RendererV2 newRenderer = new PUSH4RendererV2(15, 25, 20, push4Core, "new metadata", 50, owner);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        orchestrator.setRenderer(IPUSH4RendererV2(address(newRenderer)));
    }

    /*//////////////////////////////////////////////////////////////
                          ISPROXY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isProxy_returnsTrueForRegisteredProxy() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));

        assertTrue(orchestrator.isProxy(IPUSH4Proxy(address(proxy1))));
    }

    function test_isProxy_returnsFalseForUnregisteredProxy() public view {
        assertFalse(orchestrator.isProxy(IPUSH4Proxy(address(proxy1))));
    }

    function test_isProxy_returnsFalseAfterUnregister() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.unregisterProxy(IPUSH4Proxy(address(proxy1)));

        assertFalse(orchestrator.isProxy(IPUSH4Proxy(address(proxy1))));
    }

    function test_isProxy_returnsTrueForMultipleProxies() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy3)));

        assertTrue(orchestrator.isProxy(IPUSH4Proxy(address(proxy1))));
        assertTrue(orchestrator.isProxy(IPUSH4Proxy(address(proxy2))));
        assertTrue(orchestrator.isProxy(IPUSH4Proxy(address(proxy3))));
    }

    function test_isProxy_returnsFalseForZeroAddress() public view {
        assertFalse(orchestrator.isProxy(IPUSH4Proxy(address(0))));
    }

    /*//////////////////////////////////////////////////////////////
                         ISCREATOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isCreator_returnsTrueForRegisteredCreator() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));

        assertTrue(orchestrator.isCreator(creator1));
    }

    function test_isCreator_returnsFalseForNonCreator() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));

        assertFalse(orchestrator.isCreator(alice));
    }

    function test_isCreator_returnsTrueForAnyRegisteredCreator() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy3)));

        assertTrue(orchestrator.isCreator(creator1));
        assertTrue(orchestrator.isCreator(creator2));
        assertTrue(orchestrator.isCreator(creator3));
    }

    function test_isCreator_returnsFalseWhenNoProxiesRegistered() public view {
        assertFalse(orchestrator.isCreator(creator1));
    }

    function test_isCreator_returnsFalseAfterProxyUnregistered() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        assertTrue(orchestrator.isCreator(creator1));

        orchestrator.unregisterProxy(IPUSH4Proxy(address(proxy1)));
        assertFalse(orchestrator.isCreator(creator1));
    }

    /*//////////////////////////////////////////////////////////////
                    GETCURRENTPROXYINDEX TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getCurrentProxyIndex_returnsZeroForSingleProxy() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));

        assertEq(orchestrator.getCurrentProxyIndex(), 0);
    }

    function test_getCurrentProxyIndex_rotatesBasedOnBlockNumber() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy3)));

        // Block 0 -> index 0
        vm.roll(0);
        assertEq(orchestrator.getCurrentProxyIndex(), 0);

        // Block 100 -> index 1
        vm.roll(100);
        assertEq(orchestrator.getCurrentProxyIndex(), 1);

        // Block 200 -> index 2
        vm.roll(200);
        assertEq(orchestrator.getCurrentProxyIndex(), 2);

        // Block 300 -> index 0 (wraps around)
        vm.roll(300);
        assertEq(orchestrator.getCurrentProxyIndex(), 0);
    }

    function test_getCurrentProxyIndex_revertsWhenNoProxiesRegistered() public {
        vm.expectRevert(PUSH4OrchestratorProxy.NoProxiesRegistered.selector);
        orchestrator.getCurrentProxyIndex();
    }

    function test_getCurrentProxyIndex_usesRendererBlockInterval() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));

        // With BLOCK_INTERVAL = 100 and 2 proxies:
        // Blocks 0-99 -> index 0
        // Blocks 100-199 -> index 1
        // Blocks 200-299 -> index 0

        vm.roll(50);
        assertEq(orchestrator.getCurrentProxyIndex(), 0);

        vm.roll(150);
        assertEq(orchestrator.getCurrentProxyIndex(), 1);

        vm.roll(250);
        assertEq(orchestrator.getCurrentProxyIndex(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                      GETCURRENTPROXY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getCurrentProxy_returnsCorrectProxy() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));

        assertEq(address(orchestrator.getCurrentProxy()), address(proxy1));
    }

    function test_getCurrentProxy_rotatesWithBlockNumber() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));

        vm.roll(0);
        assertEq(address(orchestrator.getCurrentProxy()), address(proxy1));

        vm.roll(100);
        assertEq(address(orchestrator.getCurrentProxy()), address(proxy2));

        vm.roll(200);
        assertEq(address(orchestrator.getCurrentProxy()), address(proxy1));
    }

    function test_getCurrentProxy_revertsWhenNoProxiesRegistered() public {
        vm.expectRevert(PUSH4OrchestratorProxy.NoProxiesRegistered.selector);
        orchestrator.getCurrentProxy();
    }

    /*//////////////////////////////////////////////////////////////
                          EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_execute_callsCurrentProxy() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));

        bytes4 selector = bytes4(0x12345678);
        bytes4 result = orchestrator.execute(selector);

        // MockPUSH4Proxy in passthrough mode returns the selector as-is
        assertEq(result, selector);
    }

    function test_execute_usesCorrectProxyBasedOnBlock() public {
        // Set different transform modes for each proxy
        proxy1.setTransformMode(0); // passthrough
        proxy2.setTransformMode(1); // invert

        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));

        bytes4 selector = bytes4(0x10203040);

        // At block 0, should use proxy1 (passthrough)
        vm.roll(0);
        bytes4 result1 = orchestrator.execute(selector);
        assertEq(result1, selector);

        // At block 100, should use proxy2 (invert)
        vm.roll(100);
        bytes4 result2 = orchestrator.execute(selector);
        // Inverted: 255-16=239, 255-32=223, 255-48=207
        bytes4 expected =
            bytes4(bytes.concat(bytes1(uint8(239)), bytes1(uint8(223)), bytes1(uint8(207)), bytes1(uint8(64))));
        assertEq(result2, expected);
    }

    function test_execute_revertsWhenNoProxiesRegistered() public {
        vm.expectRevert(PUSH4OrchestratorProxy.NoProxiesRegistered.selector);
        orchestrator.execute(bytes4(0x12345678));
    }

    /*//////////////////////////////////////////////////////////////
                      GETCURRENTCREATOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getCurrentCreator_returnsCorrectCreator() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));

        IPUSH4Proxy.Creator memory creatorInfo = orchestrator.getCurrentCreator();
        assertEq(creatorInfo.wallet, creator1);
        assertEq(creatorInfo.name, "Creator 1");
    }

    function test_getCurrentCreator_rotatesWithBlockNumber() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));

        vm.roll(0);
        assertEq(orchestrator.getCurrentCreator().wallet, creator1);

        vm.roll(100);
        assertEq(orchestrator.getCurrentCreator().wallet, creator2);
    }

    /*//////////////////////////////////////////////////////////////
                    BLOCKSUNTILNEXTPROXY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_blocksUntilNextProxy_returnsCorrectValue() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));

        vm.roll(0);
        assertEq(orchestrator.blocksUntilNextProxy(), 100);

        vm.roll(50);
        assertEq(orchestrator.blocksUntilNextProxy(), 50);

        vm.roll(99);
        assertEq(orchestrator.blocksUntilNextProxy(), 1);

        vm.roll(100);
        assertEq(orchestrator.blocksUntilNextProxy(), 100);
    }

    function test_blocksUntilNextProxy_returnsZeroWhenNoProxies() public view {
        assertEq(orchestrator.blocksUntilNextProxy(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        PROXYATBLOCK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_proxyAtBlock_returnsCorrectIndex() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy3)));

        assertEq(orchestrator.proxyAtBlock(0), 0);
        assertEq(orchestrator.proxyAtBlock(50), 0);
        assertEq(orchestrator.proxyAtBlock(100), 1);
        assertEq(orchestrator.proxyAtBlock(200), 2);
        assertEq(orchestrator.proxyAtBlock(300), 0);
        assertEq(orchestrator.proxyAtBlock(1000), 1); // 1000 / 100 = 10, 10 % 3 = 1
    }

    function test_proxyAtBlock_revertsWhenNoProxiesRegistered() public {
        vm.expectRevert(PUSH4OrchestratorProxy.NoProxiesRegistered.selector);
        orchestrator.proxyAtBlock(100);
    }

    /*//////////////////////////////////////////////////////////////
                         PROXYCOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_proxyCount_returnsZeroInitially() public view {
        assertEq(orchestrator.proxyCount(), 0);
    }

    function test_proxyCount_incrementsOnRegister() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        assertEq(orchestrator.proxyCount(), 1);

        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));
        assertEq(orchestrator.proxyCount(), 2);
    }

    function test_proxyCount_decrementsOnUnregister() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));

        orchestrator.unregisterProxy(IPUSH4Proxy(address(proxy1)));
        assertEq(orchestrator.proxyCount(), 1);
    }

    /*//////////////////////////////////////////////////////////////
                         GETPROXYAT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getProxyAt_returnsCorrectProxy() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));

        assertEq(address(orchestrator.getProxyAt(0)), address(proxy1));
        assertEq(address(orchestrator.getProxyAt(1)), address(proxy2));
    }

    function test_getProxyAt_revertsForOutOfBoundsIndex() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));

        vm.expectRevert();
        orchestrator.getProxyAt(1);
    }

    /*//////////////////////////////////////////////////////////////
                       GETALLCREATORS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getAllCreators_returnsEmptyArrayInitially() public view {
        IPUSH4Proxy.Creator[] memory creators = orchestrator.getAllCreators();
        assertEq(creators.length, 0);
    }

    function test_getAllCreators_returnsAllCreators() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy3)));

        IPUSH4Proxy.Creator[] memory creators = orchestrator.getAllCreators();

        assertEq(creators.length, 3);
        assertEq(creators[0].wallet, creator1);
        assertEq(creators[0].name, "Creator 1");
        assertEq(creators[1].wallet, creator2);
        assertEq(creators[1].name, "Creator 2");
        assertEq(creators[2].wallet, creator3);
        assertEq(creators[2].name, "Creator 3");
    }

    function test_getAllCreators_reflectsUnregister() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));

        orchestrator.unregisterProxy(IPUSH4Proxy(address(proxy1)));

        IPUSH4Proxy.Creator[] memory creators = orchestrator.getAllCreators();
        assertEq(creators.length, 1);
        assertEq(creators[0].wallet, creator2);
    }

    /*//////////////////////////////////////////////////////////////
                      INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fullRotationCycle() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy3)));

        // Test a full rotation cycle
        for (uint256 i = 0; i < 6; i++) {
            vm.roll(i * BLOCK_INTERVAL);
            uint256 expectedIndex = i % 3;
            assertEq(orchestrator.getCurrentProxyIndex(), expectedIndex);

            address expectedProxy;
            if (expectedIndex == 0) expectedProxy = address(proxy1);
            else if (expectedIndex == 1) expectedProxy = address(proxy2);
            else expectedProxy = address(proxy3);

            assertEq(address(orchestrator.getCurrentProxy()), expectedProxy);
        }
    }

    function test_dynamicProxyAdditionAffectsRotation() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));

        // With 1 proxy, always index 0
        vm.roll(100);
        assertEq(orchestrator.getCurrentProxyIndex(), 0);

        // Add second proxy
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));

        // With 2 proxies: 100 / 100 = 1, 1 % 2 = 1
        assertEq(orchestrator.getCurrentProxyIndex(), 1);
    }

    function test_dynamicProxyRemovalAffectsRotation() public {
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy3)));

        vm.roll(200);
        // 200 / 100 = 2, 2 % 3 = 2
        assertEq(orchestrator.getCurrentProxyIndex(), 2);

        // Remove proxy3
        orchestrator.unregisterProxy(IPUSH4Proxy(address(proxy3)));

        // With 2 proxies: 200 / 100 = 2, 2 % 2 = 0
        assertEq(orchestrator.getCurrentProxyIndex(), 0);
    }
}

