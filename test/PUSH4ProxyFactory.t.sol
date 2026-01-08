// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";
import { PUSH4ProxyFactory } from "../src/PUSH4ProxyFactory.sol";
import { IPUSH4Proxy } from "../src/interface/IPUSH4Proxy.sol";
import { MockPUSH4Proxy } from "./mocks/MockPUSH4Proxy.sol";
import { MockInvalidProxy } from "./mocks/MockInvalidProxy.sol";

contract PUSH4ProxyFactoryTest is Test {
    PUSH4ProxyFactory public factory;

    MockPUSH4Proxy public proxy1;
    MockPUSH4Proxy public proxy2;
    MockPUSH4Proxy public proxy3;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public creator1 = makeAddr("creator1");
    address public creator2 = makeAddr("creator2");
    address public creator3 = makeAddr("creator3");

    function setUp() public {
        factory = new PUSH4ProxyFactory();

        // Deploy mock proxies with different creators
        proxy1 = new MockPUSH4Proxy("Proxy 1", "First proxy", "Creator 1", creator1);
        proxy2 = new MockPUSH4Proxy("Proxy 2", "Second proxy", "Creator 2", creator2);
        proxy3 = new MockPUSH4Proxy("Proxy 3", "Third proxy", "Creator 3", creator3);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_deploy_deploysAndRegistersProxy() public {
        bytes memory bytecode = _getMockProxyBytecode("Test Proxy", "Test desc", "Test Creator", alice);

        IPUSH4Proxy deployed = factory.deploy(bytecode);

        assertEq(factory.proxyCount(), 1);
        assertEq(address(factory.getProxyAt(0)), address(deployed));
        assertTrue(factory.isRegistered(address(deployed)));
    }

    function test_deploy_emitsProxyDeployedEvent() public {
        bytes memory bytecode = _getMockProxyBytecode("Test Proxy", "Test desc", "Test Creator", alice);

        vm.expectEmit(false, true, false, true);
        emit PUSH4ProxyFactory.ProxyDeployed(address(0), address(this), 0);

        factory.deploy(bytecode);
    }

    function test_deploy_revertsWithEmptyBytecode() public {
        vm.expectRevert(PUSH4ProxyFactory.InvalidProxy.selector);
        factory.deploy("");
    }

    function test_deploy_revertsWithInvalidBytecode() public {
        // Invalid bytecode that won't deploy a contract
        bytes memory invalidBytecode = hex"deadbeef";

        vm.expectRevert(PUSH4ProxyFactory.DeploymentFailed.selector);
        factory.deploy(invalidBytecode);
    }

    function test_deploy_revertsIfExecuteNotImplemented() public {
        // Get bytecode for MockInvalidProxy (no execute function)
        bytes memory bytecode = abi.encodePacked(type(MockInvalidProxy).creationCode, abi.encode("Invalid Proxy"));

        vm.expectRevert(PUSH4ProxyFactory.InvalidProxy.selector);
        factory.deploy(bytecode);
    }

    function test_deploy_setsProxyIndex() public {
        bytes memory bytecode = _getMockProxyBytecode("Test Proxy", "Test desc", "Test Creator", alice);

        IPUSH4Proxy deployed = factory.deploy(bytecode);

        // proxyIndex is 1-indexed (index + 1)
        assertEq(factory.proxyIndex(address(deployed)), 1);
    }

    function test_deploy_multipleProxies_setsCorrectIndices() public {
        bytes memory bytecode1 = _getMockProxyBytecode("Proxy 1", "desc", "Creator", alice);
        bytes memory bytecode2 = _getMockProxyBytecode("Proxy 2", "desc", "Creator", bob);

        IPUSH4Proxy deployed1 = factory.deploy(bytecode1);
        IPUSH4Proxy deployed2 = factory.deploy(bytecode2);

        assertEq(factory.proxyIndex(address(deployed1)), 1); // index 0 + 1
        assertEq(factory.proxyIndex(address(deployed2)), 2); // index 1 + 1
    }

    /*//////////////////////////////////////////////////////////////
                           REGISTER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_register_registersExistingProxy() public {
        factory.register(IPUSH4Proxy(address(proxy1)));

        assertEq(factory.proxyCount(), 1);
        assertEq(address(factory.getProxyAt(0)), address(proxy1));
        assertTrue(factory.isRegistered(address(proxy1)));
    }

    function test_register_emitsProxyRegisteredEvent() public {
        vm.expectEmit(true, true, false, true);
        emit PUSH4ProxyFactory.ProxyRegistered(address(proxy1), address(this), 0);

        factory.register(IPUSH4Proxy(address(proxy1)));
    }

    function test_register_emitsEventWithCorrectIndex() public {
        factory.register(IPUSH4Proxy(address(proxy1)));

        vm.expectEmit(true, true, false, true);
        emit PUSH4ProxyFactory.ProxyRegistered(address(proxy2), address(this), 1);

        factory.register(IPUSH4Proxy(address(proxy2)));
    }

    function test_register_revertsWithZeroAddress() public {
        vm.expectRevert(PUSH4ProxyFactory.InvalidProxy.selector);
        factory.register(IPUSH4Proxy(address(0)));
    }

    function test_register_revertsWithEOA() public {
        vm.expectRevert(PUSH4ProxyFactory.NotAContract.selector);
        factory.register(IPUSH4Proxy(alice));
    }

    function test_register_revertsWhenAlreadyRegistered() public {
        factory.register(IPUSH4Proxy(address(proxy1)));

        vm.expectRevert(PUSH4ProxyFactory.ProxyAlreadyRegistered.selector);
        factory.register(IPUSH4Proxy(address(proxy1)));
    }

    function test_register_revertsIfExecuteNotImplemented() public {
        MockInvalidProxy invalidProxy = new MockInvalidProxy("Invalid");

        vm.expectRevert(PUSH4ProxyFactory.InvalidProxy.selector);
        factory.register(IPUSH4Proxy(address(invalidProxy)));
    }

    function test_register_setsProxyIndex() public {
        factory.register(IPUSH4Proxy(address(proxy1)));

        // proxyIndex is 1-indexed (index + 1)
        assertEq(factory.proxyIndex(address(proxy1)), 1);
    }

    function test_register_multipleProxies_setsCorrectIndices() public {
        factory.register(IPUSH4Proxy(address(proxy1)));
        factory.register(IPUSH4Proxy(address(proxy2)));
        factory.register(IPUSH4Proxy(address(proxy3)));

        assertEq(factory.proxyIndex(address(proxy1)), 1); // index 0 + 1
        assertEq(factory.proxyIndex(address(proxy2)), 2); // index 1 + 1
        assertEq(factory.proxyIndex(address(proxy3)), 3); // index 2 + 1
    }

    function test_register_anyoneCanRegister() public {
        vm.prank(alice);
        factory.register(IPUSH4Proxy(address(proxy1)));

        vm.prank(bob);
        factory.register(IPUSH4Proxy(address(proxy2)));

        assertEq(factory.proxyCount(), 2);
    }

    /*//////////////////////////////////////////////////////////////
                         ISREGISTERED TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isRegistered_returnsFalseInitially() public view {
        assertFalse(factory.isRegistered(address(proxy1)));
        assertFalse(factory.isRegistered(alice));
        assertFalse(factory.isRegistered(address(0)));
    }

    function test_isRegistered_returnsTrueAfterRegister() public {
        factory.register(IPUSH4Proxy(address(proxy1)));

        assertTrue(factory.isRegistered(address(proxy1)));
    }

    function test_isRegistered_returnsTrueAfterDeploy() public {
        bytes memory bytecode = _getMockProxyBytecode("Test Proxy", "desc", "Creator", alice);

        IPUSH4Proxy deployed = factory.deploy(bytecode);

        assertTrue(factory.isRegistered(address(deployed)));
    }

    function test_isRegistered_returnsFalseForOtherProxies() public {
        factory.register(IPUSH4Proxy(address(proxy1)));

        assertTrue(factory.isRegistered(address(proxy1)));
        assertFalse(factory.isRegistered(address(proxy2)));
        assertFalse(factory.isRegistered(address(proxy3)));
    }

    /*//////////////////////////////////////////////////////////////
                          PROXYCOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_proxyCount_returnsZeroInitially() public view {
        assertEq(factory.proxyCount(), 0);
    }

    function test_proxyCount_incrementsOnRegister() public {
        factory.register(IPUSH4Proxy(address(proxy1)));
        assertEq(factory.proxyCount(), 1);

        factory.register(IPUSH4Proxy(address(proxy2)));
        assertEq(factory.proxyCount(), 2);

        factory.register(IPUSH4Proxy(address(proxy3)));
        assertEq(factory.proxyCount(), 3);
    }

    function test_proxyCount_incrementsOnDeploy() public {
        bytes memory bytecode1 = _getMockProxyBytecode("Proxy 1", "desc", "Creator", alice);
        bytes memory bytecode2 = _getMockProxyBytecode("Proxy 2", "desc", "Creator", bob);

        factory.deploy(bytecode1);
        assertEq(factory.proxyCount(), 1);

        factory.deploy(bytecode2);
        assertEq(factory.proxyCount(), 2);
    }

    /*//////////////////////////////////////////////////////////////
                          GETPROXYAT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getProxyAt_returnsCorrectProxy() public {
        factory.register(IPUSH4Proxy(address(proxy1)));
        factory.register(IPUSH4Proxy(address(proxy2)));
        factory.register(IPUSH4Proxy(address(proxy3)));

        assertEq(address(factory.getProxyAt(0)), address(proxy1));
        assertEq(address(factory.getProxyAt(1)), address(proxy2));
        assertEq(address(factory.getProxyAt(2)), address(proxy3));
    }

    function test_getProxyAt_revertsWithIndexOutOfBounds() public {
        vm.expectRevert(PUSH4ProxyFactory.IndexOutOfBounds.selector);
        factory.getProxyAt(0);
    }

    function test_getProxyAt_revertsWithIndexOutOfBounds_afterRegistration() public {
        factory.register(IPUSH4Proxy(address(proxy1)));

        vm.expectRevert(PUSH4ProxyFactory.IndexOutOfBounds.selector);
        factory.getProxyAt(1);
    }

    /*//////////////////////////////////////////////////////////////
                      GETPROXIES (PAGINATION) TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getProxies_returnsEmptyWhenNoProxies() public view {
        IPUSH4Proxy[] memory result = factory.getProxies(0, 10);
        assertEq(result.length, 0);
    }

    function test_getProxies_returnsAllWhenLimitExceedsCount() public {
        factory.register(IPUSH4Proxy(address(proxy1)));
        factory.register(IPUSH4Proxy(address(proxy2)));

        IPUSH4Proxy[] memory result = factory.getProxies(0, 100);

        assertEq(result.length, 2);
        assertEq(address(result[0]), address(proxy1));
        assertEq(address(result[1]), address(proxy2));
    }

    function test_getProxies_returnsCorrectSlice() public {
        factory.register(IPUSH4Proxy(address(proxy1)));
        factory.register(IPUSH4Proxy(address(proxy2)));
        factory.register(IPUSH4Proxy(address(proxy3)));

        // Get middle element only
        IPUSH4Proxy[] memory result = factory.getProxies(1, 1);

        assertEq(result.length, 1);
        assertEq(address(result[0]), address(proxy2));
    }

    function test_getProxies_returnsCorrectSlice_fromOffset() public {
        factory.register(IPUSH4Proxy(address(proxy1)));
        factory.register(IPUSH4Proxy(address(proxy2)));
        factory.register(IPUSH4Proxy(address(proxy3)));

        // Get last two elements
        IPUSH4Proxy[] memory result = factory.getProxies(1, 10);

        assertEq(result.length, 2);
        assertEq(address(result[0]), address(proxy2));
        assertEq(address(result[1]), address(proxy3));
    }

    function test_getProxies_returnsEmptyWhenOffsetExceedsLength() public {
        factory.register(IPUSH4Proxy(address(proxy1)));

        IPUSH4Proxy[] memory result = factory.getProxies(5, 10);

        assertEq(result.length, 0);
    }

    function test_getProxies_handlesZeroLimit() public {
        factory.register(IPUSH4Proxy(address(proxy1)));
        factory.register(IPUSH4Proxy(address(proxy2)));

        IPUSH4Proxy[] memory result = factory.getProxies(0, 0);

        assertEq(result.length, 0);
    }

    function test_getProxies_handlesExactBoundary() public {
        factory.register(IPUSH4Proxy(address(proxy1)));
        factory.register(IPUSH4Proxy(address(proxy2)));
        factory.register(IPUSH4Proxy(address(proxy3)));

        // Request exactly what's available from offset
        IPUSH4Proxy[] memory result = factory.getProxies(1, 2);

        assertEq(result.length, 2);
        assertEq(address(result[0]), address(proxy2));
        assertEq(address(result[1]), address(proxy3));
    }

    /*//////////////////////////////////////////////////////////////
                         PROXYINDEX TESTS
    //////////////////////////////////////////////////////////////*/

    function test_proxyIndex_returnsZeroForUnregistered() public view {
        assertEq(factory.proxyIndex(address(proxy1)), 0);
        assertEq(factory.proxyIndex(alice), 0);
        assertEq(factory.proxyIndex(address(0)), 0);
    }

    function test_proxyIndex_returnsOnePlusIndexForRegistered() public {
        factory.register(IPUSH4Proxy(address(proxy1)));
        factory.register(IPUSH4Proxy(address(proxy2)));
        factory.register(IPUSH4Proxy(address(proxy3)));

        // proxyIndex stores index + 1
        assertEq(factory.proxyIndex(address(proxy1)), 1); // array index 0
        assertEq(factory.proxyIndex(address(proxy2)), 2); // array index 1
        assertEq(factory.proxyIndex(address(proxy3)), 3); // array index 2
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_multipleRegistrations_maintainsCorrectOrder() public {
        factory.register(IPUSH4Proxy(address(proxy1)));
        factory.register(IPUSH4Proxy(address(proxy2)));
        factory.register(IPUSH4Proxy(address(proxy3)));

        // Verify order is preserved
        assertEq(address(factory.getProxyAt(0)), address(proxy1));
        assertEq(address(factory.getProxyAt(1)), address(proxy2));
        assertEq(address(factory.getProxyAt(2)), address(proxy3));

        // Verify count
        assertEq(factory.proxyCount(), 3);

        // Verify all are registered
        assertTrue(factory.isRegistered(address(proxy1)));
        assertTrue(factory.isRegistered(address(proxy2)));
        assertTrue(factory.isRegistered(address(proxy3)));
    }

    function test_deployAndRegister_bothWork() public {
        // Register an existing proxy
        factory.register(IPUSH4Proxy(address(proxy1)));

        // Deploy a new proxy
        bytes memory bytecode = _getMockProxyBytecode("Deployed Proxy", "desc", "Creator", alice);
        IPUSH4Proxy deployed = factory.deploy(bytecode);

        // Register another existing proxy
        factory.register(IPUSH4Proxy(address(proxy2)));

        // Verify all three are registered in correct order
        assertEq(factory.proxyCount(), 3);
        assertEq(address(factory.getProxyAt(0)), address(proxy1));
        assertEq(address(factory.getProxyAt(1)), address(deployed));
        assertEq(address(factory.getProxyAt(2)), address(proxy2));

        // Verify indices
        assertEq(factory.proxyIndex(address(proxy1)), 1);
        assertEq(factory.proxyIndex(address(deployed)), 2);
        assertEq(factory.proxyIndex(address(proxy2)), 3);
    }

    function test_differentCallersCanRegisterProxies() public {
        vm.prank(alice);
        factory.register(IPUSH4Proxy(address(proxy1)));

        vm.prank(bob);
        factory.register(IPUSH4Proxy(address(proxy2)));

        vm.prank(creator1);
        factory.register(IPUSH4Proxy(address(proxy3)));

        assertEq(factory.proxyCount(), 3);
    }

    function test_deployedProxyFunctionsCorrectly() public {
        bytes memory bytecode = _getMockProxyBytecode("Test Proxy", "Test Description", "Test Creator", alice);

        IPUSH4Proxy deployed = factory.deploy(bytecode);

        // Verify the deployed proxy works
        bytes4 testSelector = bytes4(0x12345678);
        bytes4 result = deployed.execute(testSelector);
        assertEq(result, testSelector); // MockPUSH4Proxy in passthrough mode

        // Verify metadata
        assertEq(deployed.title(), "Test Proxy");
        assertEq(deployed.description(), "Test Description");

        IPUSH4Proxy.Creator memory creatorInfo = deployed.creator();
        assertEq(creatorInfo.name, "Test Creator");
        assertEq(creatorInfo.wallet, alice);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _getMockProxyBytecode(
        string memory proxyTitle,
        string memory proxyDescription,
        string memory creatorName,
        address creatorWallet
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            type(MockPUSH4Proxy).creationCode, abi.encode(proxyTitle, proxyDescription, creatorName, creatorWallet)
        );
    }
}

