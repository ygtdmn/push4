// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test, console2 } from "forge-std/Test.sol";
import { PUSH4 } from "../src/PUSH4.sol";
import { PUSH4Core } from "../src/PUSH4Core.sol";
import { PUSH4RendererV2 } from "../src/PUSH4RendererV2.sol";
import { PUSH4RendererRouter } from "../src/PUSH4RendererRouter.sol";
import { PUSH4OrchestratorProxy } from "../src/PUSH4OrchestratorProxy.sol";
import { PUSH4ProxyTemplate } from "../src/PUSH4ProxyTemplate.sol";
import { IPUSH4Core } from "../src/interface/IPUSH4Core.sol";
import { IPUSH4Renderer } from "../src/interface/IPUSH4Renderer.sol";
import { IPUSH4RendererV2 } from "../src/interface/IPUSH4RendererV2.sol";
import { IPUSH4Proxy } from "../src/interface/IPUSH4Proxy.sol";
import { MockPUSH4Proxy } from "./mocks/MockPUSH4Proxy.sol";
import { IMURIProtocol } from "../src/interface/IMURIProtocol.sol";
import { LibString } from "solady/utils/LibString.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title PUSH4IntegrationForkTest
 * @notice Integration tests using mainnet fork to test tokenURI with multiple proxies
 * @dev Run with: forge test --match-contract PUSH4IntegrationForkTest --fork-url <RPC_URL> -vvv
 */
contract PUSH4IntegrationForkTest is Test {
    // Deployed mainnet contract addresses
    address constant PUSH4_ADDRESS = 0x000000630bf663df3ff850DD34a28Fb7D4d52170;
    address constant PUSH4_CORE_ADDRESS = 0x00000063266aAAeDD489e4956153855626E44061;
    address constant RENDERER_ADDRESS = 0x00000063Bbe182593913e09b8A481D58ADc31042;
    address constant RENDERER_ROUTER_ADDRESS = 0x000000636fAc63F4f4C12c8674Fb5D11f9A08753;
    address constant MURI_PROTOCOL_ADDRESS = 0x0000000000C2A0B63ab4aA971B08B905E5875b01;

    // Mainnet contracts
    PUSH4 public push4;
    PUSH4Core public push4Core;
    PUSH4RendererRouter public rendererRouter;

    // New contracts we deploy on fork
    PUSH4RendererV2 public rendererV2;
    PUSH4OrchestratorProxy public orchestrator;
    IMURIProtocol public muriProtocol;

    // Multiple proxies for testing rotation
    MockPUSH4Proxy public proxy1;
    MockPUSH4Proxy public proxy2;
    MockPUSH4Proxy public proxy3;

    address public deployer = makeAddr("deployer");
    address public creator1 = makeAddr("creator1");
    address public creator2 = makeAddr("creator2");
    address public creator3 = makeAddr("creator3");

    uint256 public constant BLOCK_INTERVAL = 100;

    string constant METADATA = unicode"\"name\": \"PUSH4\",\"description\": \"Integration test metadata\"";

    function setUp() public {
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY is not set");
        }

        // Otherwise, run the test against the mainnet fork.
        vm.createSelectFork({ urlOrAlias: "mainnet" });
        // Reference existing mainnet contracts
        push4 = PUSH4(PUSH4_ADDRESS);
        push4Core = PUSH4Core(PUSH4_CORE_ADDRESS);
        rendererRouter = PUSH4RendererRouter(RENDERER_ROUTER_ADDRESS);

        // Get the actual token owner from mainnet
        address actualTokenOwner = push4Core.ownerOf(0);
        address routerOwner = rendererRouter.owner();

        // Reference deployed MURI Protocol
        muriProtocol = IMURIProtocol(MURI_PROTOCOL_ADDRESS);

        // Deploy new RendererV2
        vm.startPrank(deployer);
        rendererV2 = new PUSH4RendererV2(15, 25, 20, IPUSH4Core(address(push4Core)), METADATA, BLOCK_INTERVAL, deployer);

        // Use deployed MURI protocol
        rendererV2.setMURIProtocol(MURI_PROTOCOL_ADDRESS);

        // Deploy orchestrator
        orchestrator =
            new PUSH4OrchestratorProxy(deployer, IPUSH4RendererV2(address(rendererV2)), IERC721(address(push4Core)));

        // Deploy multiple proxies with different transformations
        proxy1 = new MockPUSH4Proxy("Passthrough", "Original colors", "Creator 1", creator1);
        proxy1.setTransformMode(0); // passthrough

        proxy2 = new MockPUSH4Proxy("Inverted", "Inverted colors", "Creator 2", creator2);
        proxy2.setTransformMode(1); // invert

        proxy3 = new MockPUSH4Proxy("Grayscale", "Grayscale colors", "Creator 3", creator3);
        proxy3.setTransformMode(2); // grayscale

        // Register all proxies with orchestrator
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy1)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy2)));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy3)));
        vm.stopPrank();

        // Update renderer via the RendererRouter (bypasses grace period)
        // The router owner can change the underlying renderer (if not locked)
        if (!rendererRouter.isLocked()) {
            vm.prank(routerOwner);
            rendererRouter.setRenderer(IPUSH4Renderer(address(rendererV2)));
        }

        // Set proxy and mode as the actual TOKEN owner (not contract owner)
        vm.startPrank(actualTokenOwner);
        push4Core.setProxy(address(orchestrator));
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                          BASIC FORK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fork_push4ContractExists() public view {
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(PUSH4_ADDRESS)
        }
        assertGt(codeSize, 0, "PUSH4 contract should exist on mainnet fork");
    }

    function test_fork_push4CoreContractExists() public view {
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(PUSH4_CORE_ADDRESS)
        }
        assertGt(codeSize, 0, "PUSH4Core contract should exist on mainnet fork");
    }

    function test_fork_push4CoreReferencesCorrectPush4() public view {
        assertEq(push4Core.push4(), PUSH4_ADDRESS, "PUSH4Core should reference correct PUSH4");
    }

    function test_fork_tokenIsMinted() public view {
        // Token should already be minted on mainnet
        assertEq(push4Core.totalSupply(), 1, "Token should be minted");
    }

    /*//////////////////////////////////////////////////////////////
                      RENDERER V2 INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fork_rendererV2IsSet() public view {
        // push4Core.renderer() points to RendererRouter on mainnet
        // The router then delegates to our rendererV2
        assertEq(address(push4Core.renderer()), address(rendererRouter), "Router should be set on push4Core");

        // If router is not locked, it should point to our rendererV2
        if (!rendererRouter.isLocked()) {
            assertEq(address(rendererRouter.renderer()), address(rendererV2), "RendererV2 should be set on router");
        }
    }

    function test_fork_tokenURI_returnsValidData() public view {
        string memory uri = push4Core.tokenURI(0);

        // Should be a data URI
        assertTrue(LibString.startsWith(uri, "data:application/json;base64,"), "Should be JSON data URI");
    }

    function test_fork_tokenURI_containsMetadata() public view {
        string memory uri = push4Core.tokenURI(0);

        // Decode the base64 content
        string memory base64Part = LibString.slice(uri, 29, bytes(uri).length);
        string memory metadata = string(Base64.decode(base64Part));

        // Should contain expected fields
        assertTrue(LibString.contains(metadata, '"name"'), "Should contain name");
        assertTrue(LibString.contains(metadata, '"description"'), "Should contain description");
        assertTrue(LibString.contains(metadata, '"image"'), "Should contain image");
        assertTrue(LibString.contains(metadata, "PUSH4"), "Should contain PUSH4");
    }

    function test_fork_tokenURI_containsAnimationUrl() public view {
        // In Executed mode with MURI protocol set, should have animation_url
        string memory uri = push4Core.tokenURI(0);

        string memory base64Part = LibString.slice(uri, 29, bytes(uri).length);
        string memory metadata = string(Base64.decode(base64Part));

        assertTrue(LibString.contains(metadata, '"animation_url"'), "Should contain animation_url in Executed mode");
    }

    /*//////////////////////////////////////////////////////////////
                    ORCHESTRATOR ROTATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fork_orchestratorRotatesWithBlocks() public {
        // At block 0, should use proxy1 (index 0)
        vm.roll(0);
        assertEq(orchestrator.getCurrentProxyIndex(), 0);
        assertEq(address(orchestrator.getCurrentProxy()), address(proxy1));

        // At block 100, should use proxy2 (index 1)
        vm.roll(BLOCK_INTERVAL);
        assertEq(orchestrator.getCurrentProxyIndex(), 1);
        assertEq(address(orchestrator.getCurrentProxy()), address(proxy2));

        // At block 200, should use proxy3 (index 2)
        vm.roll(BLOCK_INTERVAL * 2);
        assertEq(orchestrator.getCurrentProxyIndex(), 2);
        assertEq(address(orchestrator.getCurrentProxy()), address(proxy3));

        // At block 300, should wrap back to proxy1 (index 0)
        vm.roll(BLOCK_INTERVAL * 3);
        assertEq(orchestrator.getCurrentProxyIndex(), 0);
        assertEq(address(orchestrator.getCurrentProxy()), address(proxy1));
    }

    function test_fork_pixelsChangeWithProxyRotation() public {
        // Get pixels at different block intervals
        vm.roll(0);
        bytes4[] memory pixels1 = rendererV2.getPixels(IPUSH4Core.Mode.Executed);

        vm.roll(BLOCK_INTERVAL);
        bytes4[] memory pixels2 = rendererV2.getPixels(IPUSH4Core.Mode.Executed);

        vm.roll(BLOCK_INTERVAL * 2);
        bytes4[] memory pixels3 = rendererV2.getPixels(IPUSH4Core.Mode.Executed);

        // All should have same length
        assertEq(pixels1.length, pixels2.length);
        assertEq(pixels2.length, pixels3.length);

        // But different values due to different transformations
        // proxy1 = passthrough, proxy2 = invert, proxy3 = grayscale
        // At least some pixels should differ between transformations
        bool foundDifference12 = false;
        bool foundDifference23 = false;

        for (uint256 i = 0; i < pixels1.length; i++) {
            if (pixels1[i] != pixels2[i]) foundDifference12 = true;
            if (pixels2[i] != pixels3[i]) foundDifference23 = true;
            if (foundDifference12 && foundDifference23) break;
        }

        assertTrue(foundDifference12, "Pixels should differ between proxy1 and proxy2");
        assertTrue(foundDifference23, "Pixels should differ between proxy2 and proxy3");
    }

    function test_fork_svgChangesWithProxyRotation() public {
        // Get SVG at different block intervals
        vm.roll(0);
        string memory svg1 = rendererV2.getSvg();

        vm.roll(BLOCK_INTERVAL);
        string memory svg2 = rendererV2.getSvg();

        // SVGs should be different (different colors)
        assertTrue(keccak256(bytes(svg1)) != keccak256(bytes(svg2)), "SVG should change when proxy rotates");
    }

    function test_fork_tokenURIChangesWithProxyRotation() public {
        // Get tokenURI at different block intervals
        vm.roll(0);
        string memory uri1 = push4Core.tokenURI(0);

        vm.roll(BLOCK_INTERVAL);
        string memory uri2 = push4Core.tokenURI(0);

        vm.roll(BLOCK_INTERVAL * 2);
        string memory uri3 = push4Core.tokenURI(0);

        // All should be valid data URIs
        assertTrue(LibString.startsWith(uri1, "data:application/json;base64,"));
        assertTrue(LibString.startsWith(uri2, "data:application/json;base64,"));
        assertTrue(LibString.startsWith(uri3, "data:application/json;base64,"));

        // But should have different content
        assertTrue(keccak256(bytes(uri1)) != keccak256(bytes(uri2)), "tokenURI should change between proxy1 and proxy2");
        assertTrue(keccak256(bytes(uri2)) != keccak256(bytes(uri3)), "tokenURI should change between proxy2 and proxy3");
    }

    /*//////////////////////////////////////////////////////////////
                    CURRENT CREATOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fork_currentCreatorRotates() public {
        vm.roll(0);
        IPUSH4Proxy.Creator memory c1 = orchestrator.getCurrentCreator();
        assertEq(c1.wallet, creator1);
        assertEq(c1.name, "Creator 1");

        vm.roll(BLOCK_INTERVAL);
        IPUSH4Proxy.Creator memory c2 = orchestrator.getCurrentCreator();
        assertEq(c2.wallet, creator2);
        assertEq(c2.name, "Creator 2");

        vm.roll(BLOCK_INTERVAL * 2);
        IPUSH4Proxy.Creator memory c3 = orchestrator.getCurrentCreator();
        assertEq(c3.wallet, creator3);
        assertEq(c3.name, "Creator 3");
    }

    function test_fork_getAllCreatorsReturnsAll() public view {
        IPUSH4Proxy.Creator[] memory creators = orchestrator.getAllCreators();

        assertEq(creators.length, 3);
        assertEq(creators[0].wallet, creator1);
        assertEq(creators[1].wallet, creator2);
        assertEq(creators[2].wallet, creator3);
    }

    /*//////////////////////////////////////////////////////////////
                    BLOCKS UNTIL NEXT PROXY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fork_blocksUntilNextProxy() public {
        vm.roll(0);
        assertEq(orchestrator.blocksUntilNextProxy(), BLOCK_INTERVAL);

        vm.roll(50);
        assertEq(orchestrator.blocksUntilNextProxy(), 50);

        vm.roll(99);
        assertEq(orchestrator.blocksUntilNextProxy(), 1);

        vm.roll(100);
        assertEq(orchestrator.blocksUntilNextProxy(), BLOCK_INTERVAL);
    }

    /*//////////////////////////////////////////////////////////////
                    PROXY EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fork_orchestratorExecuteUsesCurrentProxy() public {
        bytes4 testSelector = bytes4(0x80402000); // R=128, G=64, B=32, index=0

        // At block 0 - proxy1 (passthrough)
        vm.roll(0);
        bytes4 result1 = orchestrator.execute(testSelector);
        assertEq(result1, testSelector, "Passthrough should return same selector");

        // At block 100 - proxy2 (invert)
        vm.roll(BLOCK_INTERVAL);
        bytes4 result2 = orchestrator.execute(testSelector);
        // Inverted: R=255-128=127, G=255-64=191, B=255-32=223
        bytes4 expected2 =
            bytes4(bytes.concat(bytes1(uint8(127)), bytes1(uint8(191)), bytes1(uint8(223)), bytes1(uint8(0))));
        assertEq(result2, expected2, "Invert should invert colors");

        // At block 200 - proxy3 (grayscale)
        vm.roll(BLOCK_INTERVAL * 2);
        bytes4 result3 = orchestrator.execute(testSelector);
        // Grayscale: avg = (128 + 64 + 32) / 3 = 74
        bytes4 expected3 =
            bytes4(bytes.concat(bytes1(uint8(74)), bytes1(uint8(74)), bytes1(uint8(74)), bytes1(uint8(0))));
        assertEq(result3, expected3, "Grayscale should average colors");
    }

    /*//////////////////////////////////////////////////////////////
                    MURI PROTOCOL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fork_muriProtocolExists() public view {
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(MURI_PROTOCOL_ADDRESS)
        }
        assertGt(codeSize, 0, "MURI Protocol should exist on mainnet fork");
    }

    function test_fork_animationUrlIsDataUri() public view {
        string memory animationUrl = rendererV2.getAnimationUrl();

        // Should be a data URI (if MURI returns HTML)
        if (bytes(animationUrl).length > 0) {
            assertTrue(LibString.startsWith(animationUrl, "data:text/html;base64,"));
        }
    }

    function test_fork_animationUrlPlaceholdersReplaced() public view {
        string memory animationUrl = rendererV2.getAnimationUrl();

        if (bytes(animationUrl).length > 22) {
            // Decode to check placeholders were replaced
            string memory base64Part = LibString.slice(animationUrl, 22, bytes(animationUrl).length);
            string memory html = string(Base64.decode(base64Part));

            // Should NOT contain unreplaced placeholders
            assertFalse(LibString.contains(html, "{{BLOCK_INTERVAL}}"));
            assertFalse(LibString.contains(html, "{{CORE_ADDRESS}}"));
            assertFalse(LibString.contains(html, "{{TOKEN_ID}}"));
        }
    }

    /*//////////////////////////////////////////////////////////////
                    DYNAMIC PROXY MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fork_addingProxyAffectsRotation() public {
        // Create and register a 4th proxy
        vm.startPrank(deployer);
        MockPUSH4Proxy proxy4 = new MockPUSH4Proxy("Fourth", "Fourth proxy", "Creator 4", makeAddr("creator4"));
        orchestrator.registerProxy(IPUSH4Proxy(address(proxy4)));
        vm.stopPrank();

        // With 4 proxies: block 300 should now be index 3 (not 0)
        vm.roll(BLOCK_INTERVAL * 3);
        assertEq(orchestrator.getCurrentProxyIndex(), 3);
        assertEq(address(orchestrator.getCurrentProxy()), address(proxy4));

        // Block 400 should wrap to 0
        vm.roll(BLOCK_INTERVAL * 4);
        assertEq(orchestrator.getCurrentProxyIndex(), 0);
    }

    function test_fork_removingProxyAffectsRotation() public {
        // Remove proxy2
        vm.prank(deployer);
        orchestrator.unregisterProxy(IPUSH4Proxy(address(proxy2)));

        // With 2 proxies (proxy1 and proxy3): rotation should change
        // Note: proxy3 gets swapped to index 1 when proxy2 is removed

        vm.roll(0);
        assertEq(orchestrator.getCurrentProxyIndex(), 0);

        vm.roll(BLOCK_INTERVAL);
        assertEq(orchestrator.getCurrentProxyIndex(), 1);

        vm.roll(BLOCK_INTERVAL * 2);
        assertEq(orchestrator.getCurrentProxyIndex(), 0); // Wraps with 2 proxies
    }

    /*//////////////////////////////////////////////////////////////
                    CARVED MODE COMPARISON TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fork_carvedModePixelsUnchanged() public {
        // Get carved pixels at different blocks - should be the same
        vm.roll(0);
        bytes4[] memory carved1 = rendererV2.getPixels(IPUSH4Core.Mode.Carved);

        vm.roll(BLOCK_INTERVAL);
        bytes4[] memory carved2 = rendererV2.getPixels(IPUSH4Core.Mode.Carved);

        vm.roll(BLOCK_INTERVAL * 2);
        bytes4[] memory carved3 = rendererV2.getPixels(IPUSH4Core.Mode.Carved);

        // Carved mode should always return the same pixels (from bytecode)
        for (uint256 i = 0; i < carved1.length; i++) {
            assertEq(carved1[i], carved2[i], "Carved pixels should not change with blocks");
            assertEq(carved2[i], carved3[i], "Carved pixels should not change with blocks");
        }
    }

    function test_fork_executedModeUsesProxy() public {
        vm.roll(0);

        // Get carved vs executed pixels
        bytes4[] memory carved = rendererV2.getPixels(IPUSH4Core.Mode.Carved);
        bytes4[] memory executed = rendererV2.getPixels(IPUSH4Core.Mode.Executed);

        // With passthrough proxy (proxy1), executed should equal carved
        for (uint256 i = 0; i < carved.length; i++) {
            assertEq(executed[i], carved[i], "Passthrough proxy should not modify pixels");
        }

        // Switch to invert proxy
        vm.roll(BLOCK_INTERVAL);
        bytes4[] memory executedInverted = rendererV2.getPixels(IPUSH4Core.Mode.Executed);

        // Inverted should differ from carved
        bool foundDifference = false;
        for (uint256 i = 0; i < carved.length; i++) {
            if (executedInverted[i] != carved[i]) {
                foundDifference = true;
                break;
            }
        }
        assertTrue(foundDifference, "Inverted pixels should differ from carved");
    }

    /*//////////////////////////////////////////////////////////////
                    FULL CYCLE INTEGRATION TEST
    //////////////////////////////////////////////////////////////*/

    function test_fork_fullRotationCycleTokenURI() public {
        string memory previousUri;

        // Test multiple complete rotations
        for (uint256 cycle = 0; cycle < 2; cycle++) {
            for (uint256 proxyIndex = 0; proxyIndex < 3; proxyIndex++) {
                uint256 blockNum = (cycle * 3 + proxyIndex) * BLOCK_INTERVAL;
                vm.roll(blockNum);

                // Verify correct proxy is active
                assertEq(orchestrator.getCurrentProxyIndex(), proxyIndex);

                // Get tokenURI
                string memory uri = push4Core.tokenURI(0);

                // Should be valid
                assertTrue(LibString.startsWith(uri, "data:application/json;base64,"));

                // Should differ from previous (except first iteration)
                if (bytes(previousUri).length > 0) {
                    assertTrue(
                        keccak256(bytes(uri)) != keccak256(bytes(previousUri)),
                        "Each rotation should produce different tokenURI"
                    );
                }

                previousUri = uri;
            }
        }
    }
}

