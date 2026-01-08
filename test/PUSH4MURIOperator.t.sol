// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";
import { PUSH4MURIOperator } from "../src/PUSH4MURIOperator.sol";
import { PUSH4RendererV2 } from "../src/PUSH4RendererV2.sol";
import { PUSH4Core } from "../src/PUSH4Core.sol";
import { PUSH4 } from "../src/PUSH4.sol";
import { IPUSH4OrchestratorProxy } from "../src/interface/IPUSH4OrchestratorProxy.sol";
import { IMURIProtocol } from "../src/interface/IMURIProtocol.sol";
import { IMURIProtocolCreator } from "../src/interface/IMURIProtocolCreator.sol";
import { MockOrchestratorProxy } from "./mocks/MockOrchestratorProxy.sol";
import { MockMURIProtocol } from "./mocks/MockMURIProtocol.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract PUSH4MURIOperatorTest is Test {
    // Deterministic addresses
    address constant PUSH4_ADDRESS = 0x000000630bf663df3ff850DD34a28Fb7D4d52170;
    address constant PUSH4_CORE_ADDRESS = 0x00000063266aAAeDD489e4956153855626E44061;

    PUSH4 public push4;
    PUSH4Core public push4Core;
    PUSH4RendererV2 public rendererV2;
    MockOrchestratorProxy public orchestrator;
    MockMURIProtocol public mockMuri;
    PUSH4MURIOperator public muriOperator;

    address public owner = address(this);
    address public orchestratorOwner = makeAddr("orchestratorOwner");
    address public creatorAccount = makeAddr("creatorAccount");
    address public tokenOwner = makeAddr("tokenOwner");
    address public alice = makeAddr("alice");
    address public randomUser = makeAddr("randomUser");

    uint256 public constant TOKEN_ID = 0;

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
        rendererV2 = new PUSH4RendererV2(15, 25, 20, push4Core, "test metadata", 100, owner);
        push4Core.setRenderer(rendererV2);

        // Deploy mocks
        orchestrator = new MockOrchestratorProxy(orchestratorOwner);
        mockMuri = new MockMURIProtocol();

        // Deploy MURI Operator
        muriOperator = new PUSH4MURIOperator(
            IPUSH4OrchestratorProxy(address(orchestrator)), rendererV2, IMURIProtocol(address(mockMuri)), owner
        );
    }

    /*//////////////////////////////////////////////////////////////
                          CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsOrchestrator() public view {
        assertEq(address(muriOperator.orchestrator()), address(orchestrator));
    }

    function test_constructor_setsRenderer() public view {
        assertEq(address(muriOperator.renderer()), address(rendererV2));
    }

    function test_constructor_setsMuriProtocol() public view {
        assertEq(address(muriOperator.muriProtocol()), address(mockMuri));
    }

    function test_constructor_setsOwner() public view {
        assertEq(muriOperator.owner(), owner);
    }

    /*//////////////////////////////////////////////////////////////
                       ISTOKENOWNER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isTokenOwner_returnsTrueForOrchestratorOwner() public view {
        bool result = muriOperator.isTokenOwner(address(push4Core), orchestratorOwner, TOKEN_ID);
        assertTrue(result);
    }

    function test_isTokenOwner_returnsTrueForCreator() public {
        orchestrator.addCreator(creatorAccount);

        bool result = muriOperator.isTokenOwner(address(push4Core), creatorAccount, TOKEN_ID);
        assertTrue(result);
    }

    function test_isTokenOwner_returnsTrueForActualTokenOwner() public {
        // Mint token to tokenOwner
        push4Core.mint(tokenOwner);

        bool result = muriOperator.isTokenOwner(address(push4Core), tokenOwner, TOKEN_ID);
        assertTrue(result);
    }

    function test_isTokenOwner_returnsFalseForNonOwnerNonCreator() public view {
        bool result = muriOperator.isTokenOwner(address(push4Core), randomUser, TOKEN_ID);
        assertFalse(result);
    }

    function test_isTokenOwner_returnsFalseWhenTokenNotMinted() public view {
        // Token 0 not minted, randomUser is not orchestrator owner or creator
        bool result = muriOperator.isTokenOwner(address(push4Core), randomUser, TOKEN_ID);
        assertFalse(result);
    }

    function test_isTokenOwner_worksWhenOrchestratorIsZeroAddress() public {
        // Deploy new operator with zero orchestrator
        PUSH4MURIOperator operatorNoOrchestrator = new PUSH4MURIOperator(
            IPUSH4OrchestratorProxy(address(0)), rendererV2, IMURIProtocol(address(mockMuri)), owner
        );

        // Mint token to tokenOwner
        push4Core.mint(tokenOwner);

        // Should still work for actual token owner
        bool result = operatorNoOrchestrator.isTokenOwner(address(push4Core), tokenOwner, TOKEN_ID);
        assertTrue(result);

        // Should return false for random user
        result = operatorNoOrchestrator.isTokenOwner(address(push4Core), randomUser, TOKEN_ID);
        assertFalse(result);
    }

    function test_isTokenOwner_handlesNonERC721Contract() public view {
        // Use mockMuri which is a contract but doesn't implement IERC721
        // Should return false without reverting
        bool result = muriOperator.isTokenOwner(address(mockMuri), randomUser, TOKEN_ID);
        assertFalse(result);
    }

    function test_isTokenOwner_orchestratorOwnerTakesPrecedence() public {
        // Even if token is minted to someone else, orchestrator owner should return true
        push4Core.mint(tokenOwner);

        bool result = muriOperator.isTokenOwner(address(push4Core), orchestratorOwner, TOKEN_ID);
        assertTrue(result);
    }

    function test_isTokenOwner_creatorTakesPrecedence() public {
        // Even if token is minted to someone else, creator should return true
        push4Core.mint(tokenOwner);
        orchestrator.addCreator(creatorAccount);

        bool result = muriOperator.isTokenOwner(address(push4Core), creatorAccount, TOKEN_ID);
        assertTrue(result);
    }

    /*//////////////////////////////////////////////////////////////
                       INITIALIZETOKENDATA TESTS
    //////////////////////////////////////////////////////////////*/

    function test_initializeTokenData_revertsWhenNotOwner() public {
        IMURIProtocol.InitConfig memory config;
        bytes[] memory thumbnailChunks = new bytes[](0);
        string[] memory htmlTemplateChunks = new string[](0);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        muriOperator.initializeTokenData(address(push4Core), TOKEN_ID, config, thumbnailChunks, htmlTemplateChunks);
    }

    function test_initializeTokenData_callsMuriProtocol() public {
        IMURIProtocol.InitConfig memory config;
        bytes[] memory thumbnailChunks = new bytes[](0);
        string[] memory htmlTemplateChunks = new string[](0);

        muriOperator.initializeTokenData(address(push4Core), TOKEN_ID, config, thumbnailChunks, htmlTemplateChunks);

        assertTrue(mockMuri.initializeCalled());
    }

    /*//////////////////////////////////////////////////////////////
                       SETORCHESTRATOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setOrchestrator_revertsWhenNotOwner() public {
        MockOrchestratorProxy newOrchestrator = new MockOrchestratorProxy(alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        muriOperator.setOrchestrator(IPUSH4OrchestratorProxy(address(newOrchestrator)));
    }

    function test_setOrchestrator_emitsEvent() public {
        MockOrchestratorProxy newOrchestrator = new MockOrchestratorProxy(alice);

        vm.expectEmit(true, false, false, false);
        emit PUSH4MURIOperator.OrchestratorUpdated(address(newOrchestrator));
        muriOperator.setOrchestrator(IPUSH4OrchestratorProxy(address(newOrchestrator)));
    }

    function test_setOrchestrator_updatesState() public {
        MockOrchestratorProxy newOrchestrator = new MockOrchestratorProxy(alice);

        muriOperator.setOrchestrator(IPUSH4OrchestratorProxy(address(newOrchestrator)));
        assertEq(address(muriOperator.orchestrator()), address(newOrchestrator));
    }

    /*//////////////////////////////////////////////////////////////
                         SETRENDERER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setRenderer_revertsWhenNotOwner() public {
        PUSH4RendererV2 newRenderer = new PUSH4RendererV2(15, 25, 20, push4Core, "new metadata", 100, owner);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        muriOperator.setRenderer(newRenderer);
    }

    function test_setRenderer_emitsEvent() public {
        PUSH4RendererV2 newRenderer = new PUSH4RendererV2(15, 25, 20, push4Core, "new metadata", 100, owner);

        vm.expectEmit(true, false, false, false);
        emit PUSH4MURIOperator.RendererUpdated(address(newRenderer));
        muriOperator.setRenderer(newRenderer);
    }

    function test_setRenderer_updatesState() public {
        PUSH4RendererV2 newRenderer = new PUSH4RendererV2(15, 25, 20, push4Core, "new metadata", 100, owner);

        muriOperator.setRenderer(newRenderer);
        assertEq(address(muriOperator.renderer()), address(newRenderer));
    }

    /*//////////////////////////////////////////////////////////////
                       SETMURIPROTOCOL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setMURIProtocol_revertsWhenNotOwner() public {
        MockMURIProtocol newMuri = new MockMURIProtocol();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        muriOperator.setMURIProtocol(address(newMuri));
    }

    function test_setMURIProtocol_emitsEvent() public {
        MockMURIProtocol newMuri = new MockMURIProtocol();

        vm.expectEmit(true, false, false, false);
        emit PUSH4MURIOperator.MURIProtocolUpdated(address(newMuri));
        muriOperator.setMURIProtocol(address(newMuri));
    }

    function test_setMURIProtocol_updatesState() public {
        MockMURIProtocol newMuri = new MockMURIProtocol();

        muriOperator.setMURIProtocol(address(newMuri));
        assertEq(address(muriOperator.muriProtocol()), address(newMuri));
    }

    /*//////////////////////////////////////////////////////////////
                      SUPPORTSINTERFACE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_supportsInterface_returnsTrueForIMURIProtocolCreator() public view {
        assertTrue(muriOperator.supportsInterface(type(IMURIProtocolCreator).interfaceId));
    }

    function test_supportsInterface_returnsTrueForIERC165() public view {
        assertTrue(muriOperator.supportsInterface(type(IERC165).interfaceId));
    }

    function test_supportsInterface_returnsFalseForRandomInterface() public view {
        bytes4 randomInterfaceId = bytes4(keccak256("randomInterface()"));
        assertFalse(muriOperator.supportsInterface(randomInterfaceId));
    }

    function test_supportsInterface_returnsFalseForIERC721() public view {
        assertFalse(muriOperator.supportsInterface(type(IERC721).interfaceId));
    }
}

