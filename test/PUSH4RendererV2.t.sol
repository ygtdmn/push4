// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";
import { PUSH4 } from "../src/PUSH4.sol";
import { PUSH4Core } from "../src/PUSH4Core.sol";
import { PUSH4RendererV2 } from "../src/PUSH4RendererV2.sol";
import { PUSH4ProxyTemplate } from "../src/PUSH4ProxyTemplate.sol";
import { IPUSH4Core } from "../src/interface/IPUSH4Core.sol";
import { IPUSH4RendererV2 } from "../src/interface/IPUSH4RendererV2.sol";
import { IPUSH4Renderer } from "../src/interface/IPUSH4Renderer.sol";
import { MockMURIProtocol } from "./mocks/MockMURIProtocol.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";
import { console2 } from "forge-std/console2.sol";

contract PUSH4RendererV2Test is Test {
    // Deterministic addresses from Deploy.s.sol
    address constant PUSH4_ADDRESS = 0x000000630bf663df3ff850DD34a28Fb7D4d52170;
    address constant PUSH4_CORE_ADDRESS = 0x00000063266aAAeDD489e4956153855626E44061;

    PUSH4 public push4;
    PUSH4Core public push4Core;
    PUSH4RendererV2 public rendererV2;
    PUSH4ProxyTemplate public proxyTemplate;
    MockMURIProtocol public mockMuri;

    address public owner = address(this);
    address public tokenOwner = makeAddr("tokenOwner");
    address public alice = makeAddr("alice");

    uint256 public constant WIDTH = 15;
    uint256 public constant HEIGHT = 25;
    uint256 public constant PIXEL_SIZE = 20;
    uint256 public constant TOTAL_PIXELS = WIDTH * HEIGHT; // 375
    uint256 public constant DEFAULT_BLOCK_INTERVAL = 100;

    string constant METADATA =
        unicode'"name": "PUSH4","description": "A heavily compressed and dithered down version of Barnett Newman\'s Onement I, encoded in 375 smart contract function selectors."';

    function setUp() public {
        _fullSetupV2(owner, WIDTH, HEIGHT, PIXEL_SIZE, METADATA, DEFAULT_BLOCK_INTERVAL);
    }

    /*//////////////////////////////////////////////////////////////
                                SETUP HELPERS
      //////////////////////////////////////////////////////////////*/

    function _deployPush4() internal {
        PUSH4 tempPush4 = new PUSH4();
        vm.etch(PUSH4_ADDRESS, address(tempPush4).code);
        push4 = PUSH4(PUSH4_ADDRESS);
    }

    function _deployPush4Core(address _owner) internal {
        require(address(push4) != address(0), "PUSH4 must be deployed first");

        PUSH4Core tempCore = new PUSH4Core(address(push4), _owner);
        vm.etch(PUSH4_CORE_ADDRESS, address(tempCore).code);

        for (uint256 i = 0; i < 20; i++) {
            bytes32 slot = bytes32(i);
            bytes32 value = vm.load(address(tempCore), slot);
            vm.store(PUSH4_CORE_ADDRESS, slot, value);
        }

        push4Core = PUSH4Core(PUSH4_CORE_ADDRESS);
    }

    function _deployRendererV2(
        uint256 width,
        uint256 height,
        uint256 pixelSize,
        string memory metadata,
        uint256 blockInterval,
        address _owner
    )
        internal
    {
        require(address(push4Core) != address(0), "PUSH4Core must be deployed first");
        rendererV2 = new PUSH4RendererV2(width, height, pixelSize, push4Core, metadata, blockInterval, _owner);
    }

    function _deployProxyTemplate() internal {
        require(address(push4) != address(0), "PUSH4 must be deployed first");
        require(address(push4Core) != address(0), "PUSH4Core must be deployed first");
        proxyTemplate = new PUSH4ProxyTemplate(address(push4), address(push4Core));
    }

    function _deployMockMuri() internal {
        mockMuri = new MockMURIProtocol();
    }

    function _fullSetupV2(
        address _owner,
        uint256 width,
        uint256 height,
        uint256 pixelSize,
        string memory metadata,
        uint256 blockInterval
    )
        internal
    {
        _deployPush4();
        _deployPush4Core(_owner);
        _deployRendererV2(width, height, pixelSize, metadata, blockInterval, _owner);
        _deployProxyTemplate();
        _deployMockMuri();
        push4Core.setRenderer(rendererV2);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
      //////////////////////////////////////////////////////////////*/

    function test_constructor_revertsWithZeroBlockInterval() public {
        vm.expectRevert(IPUSH4RendererV2.InvalidBlockInterval.selector);
        new PUSH4RendererV2(WIDTH, HEIGHT, PIXEL_SIZE, push4Core, METADATA, 0, owner);
    }

    function test_constructor_setsBlockInterval() public view {
        assertEq(rendererV2.blockInterval(), DEFAULT_BLOCK_INTERVAL);
    }

    function test_constructor_setsWidthHeightPixelSize() public view {
        assertEq(rendererV2.width(), WIDTH);
        assertEq(rendererV2.height(), HEIGHT);
        assertEq(rendererV2.pixelSize(), PIXEL_SIZE);
    }

    /*//////////////////////////////////////////////////////////////
                         SETMURIPROTOCOL TESTS
      //////////////////////////////////////////////////////////////*/

    function test_setMURIProtocol_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        rendererV2.setMURIProtocol(address(mockMuri));
    }

    function test_setMURIProtocol_emitsEvent() public {
        vm.expectEmit(true, false, false, false);
        emit IPUSH4RendererV2.MURIProtocolUpdated(address(mockMuri));
        rendererV2.setMURIProtocol(address(mockMuri));
    }

    function test_setMURIProtocol_updatesState() public {
        rendererV2.setMURIProtocol(address(mockMuri));
        assertEq(address(rendererV2.muriProtocol()), address(mockMuri));
    }

    /*//////////////////////////////////////////////////////////////
                         SETBLOCKINTERVAL TESTS
      //////////////////////////////////////////////////////////////*/

    function test_setBlockInterval_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        rendererV2.setBlockInterval(200);
    }

    function test_setBlockInterval_revertsWithZeroValue() public {
        vm.expectRevert(IPUSH4RendererV2.InvalidBlockInterval.selector);
        rendererV2.setBlockInterval(0);
    }

    function test_setBlockInterval_emitsEvent() public {
        uint256 oldValue = rendererV2.blockInterval();
        uint256 newValue = 500;

        vm.expectEmit(false, false, false, true);
        emit IPUSH4RendererV2.BlockIntervalUpdated(oldValue, newValue);
        rendererV2.setBlockInterval(newValue);
    }

    function test_setBlockInterval_updatesState() public {
        uint256 newValue = 500;
        rendererV2.setBlockInterval(newValue);
        assertEq(rendererV2.blockInterval(), newValue);
    }

    /*//////////////////////////////////////////////////////////////
                         GETANIMATIONURL TESTS
      //////////////////////////////////////////////////////////////*/

    function test_getAnimationUrl_returnsEmptyWhenNoProtocol() public view {
        string memory animationUrl = rendererV2.getAnimationUrl();
        assertEq(animationUrl, "");
    }

    function test_getAnimationUrl_returnsBase64Html() public {
        rendererV2.setMURIProtocol(address(mockMuri));

        string memory animationUrl = rendererV2.getAnimationUrl();

        assertTrue(LibString.startsWith(animationUrl, "data:text/html;base64,"));
    }

    function test_getAnimationUrl_replacesBlockInterval() public {
        rendererV2.setMURIProtocol(address(mockMuri));

        string memory animationUrl = rendererV2.getAnimationUrl();

        // Decode base64 to check content
        string memory base64Part = LibString.slice(animationUrl, 22, bytes(animationUrl).length);
        string memory decodedHtml = string(Base64.decode(base64Part));

        // Should contain the block interval value, not the placeholder
        assertTrue(LibString.contains(decodedHtml, LibString.toString(DEFAULT_BLOCK_INTERVAL)));
        assertFalse(LibString.contains(decodedHtml, "{{BLOCK_INTERVAL}}"));
    }

    function test_getAnimationUrl_replacesCoreAddress() public {
        rendererV2.setMURIProtocol(address(mockMuri));

        string memory animationUrl = rendererV2.getAnimationUrl();

        // Decode base64 to check content
        string memory base64Part = LibString.slice(animationUrl, 22, bytes(animationUrl).length);
        string memory decodedHtml = string(Base64.decode(base64Part));

        // Should contain the core address, not the placeholder
        assertTrue(LibString.contains(decodedHtml, LibString.toHexStringChecksummed(address(push4Core))));
        assertFalse(LibString.contains(decodedHtml, "{{CORE_ADDRESS}}"));
    }

    function test_getAnimationUrl_replacesTokenId() public {
        rendererV2.setMURIProtocol(address(mockMuri));

        string memory animationUrl = rendererV2.getAnimationUrl();

        // Decode base64 to check content
        string memory base64Part = LibString.slice(animationUrl, 22, bytes(animationUrl).length);
        string memory decodedHtml = string(Base64.decode(base64Part));

        // TOKEN_ID is 0, should not contain the placeholder
        assertFalse(LibString.contains(decodedHtml, "{{TOKEN_ID}}"));
    }

    function test_getAnimationUrl_usesUpdatedBlockInterval() public {
        rendererV2.setMURIProtocol(address(mockMuri));
        uint256 newInterval = 999;
        rendererV2.setBlockInterval(newInterval);

        string memory animationUrl = rendererV2.getAnimationUrl();

        // Decode base64 to check content
        string memory base64Part = LibString.slice(animationUrl, 22, bytes(animationUrl).length);
        string memory decodedHtml = string(Base64.decode(base64Part));

        // Should contain the new block interval value
        assertTrue(LibString.contains(decodedHtml, LibString.toString(newInterval)));
    }

    /*//////////////////////////////////////////////////////////////
                            METADATA TESTS
      //////////////////////////////////////////////////////////////*/

    function test_getMetadata_carvedMode_noAnimationUrl() public view {
        // Default mode is Carved
        string memory metadata = rendererV2.getMetadata();

        // Should not contain animation_url field
        assertFalse(LibString.contains(metadata, "animation_url"));
    }

    function test_getMetadata_executedMode_includesAnimationUrl() public {
        // Setup executed mode
        push4Core.mint(tokenOwner);
        vm.startPrank(tokenOwner);
        push4Core.setProxy(address(proxyTemplate));
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        vm.stopPrank();

        // Set MURI protocol
        rendererV2.setMURIProtocol(address(mockMuri));

        string memory metadata = rendererV2.getMetadata();

        // Should contain animation_url field
        assertTrue(LibString.contains(metadata, "animation_url"));
    }

    function test_getMetadata_executedMode_noMuriProtocol_includesEmptyAnimationUrl() public {
        // Setup executed mode without MURI protocol
        push4Core.mint(tokenOwner);
        vm.startPrank(tokenOwner);
        push4Core.setProxy(address(proxyTemplate));
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        vm.stopPrank();

        string memory metadata = rendererV2.getMetadata();

        // Should still contain animation_url field (empty value)
        assertTrue(LibString.contains(metadata, '"animation_url": ""'));
    }

    /*//////////////////////////////////////////////////////////////
                        CORE RENDERER TESTS
      //////////////////////////////////////////////////////////////*/

    function test_getPixels_carvedMode_returnsCorrectLength() public view {
        bytes4[] memory pixels = rendererV2.getPixels(IPUSH4Core.Mode.Carved);
        assertEq(pixels.length, TOTAL_PIXELS, "Should return 375 pixels");
    }

    function test_getSvg_containsCorrectDimensions() public view {
        string memory svg = rendererV2.getSvg();

        string memory widthStr = LibString.toString(WIDTH * PIXEL_SIZE);
        string memory heightStr = LibString.toString(HEIGHT * PIXEL_SIZE);

        assertTrue(LibString.contains(svg, widthStr), "SVG should contain correct width");
        assertTrue(LibString.contains(svg, heightStr), "SVG should contain correct height");
    }

    function test_getSvg_containsViewBox() public view {
        string memory svg = rendererV2.getSvg();
        string memory viewBox = string(
            abi.encodePacked('viewBox="0 0 ', LibString.toString(WIDTH), " ", LibString.toString(HEIGHT), '"')
        );

        assertTrue(LibString.contains(svg, viewBox), "SVG should contain correct viewBox");
    }

    function test_getSvg_hasCorrectStructure() public view {
        string memory svg = rendererV2.getSvg();

        assertTrue(LibString.startsWith(svg, '<svg xmlns="http://www.w3.org/2000/svg"'), "Should start with svg tag");
        assertTrue(LibString.endsWith(svg, "</svg>"), "Should end with closing svg tag");
        assertTrue(LibString.contains(svg, 'shape-rendering="crispEdges"'), "Should have crisp edges");
    }

    function test_getSvgDataUri_encodesBase64Correctly() public view {
        string memory svg = rendererV2.getSvg();
        string memory svgDataUri = rendererV2.getSvgDataUri();

        assertTrue(LibString.startsWith(svgDataUri, "data:image/svg+xml;base64,"), "Should have correct prefix");

        string memory expectedDataUri =
            string(abi.encodePacked("data:image/svg+xml;base64,", Base64.encode(bytes(svg))));
        assertEq(svgDataUri, expectedDataUri, "Data URI should match base64 encoded SVG");
    }

    function test_getMetadataDataUri_encodesCorrectly() public view {
        string memory metadata = rendererV2.getMetadata();
        string memory metadataDataUri = rendererV2.getMetadataDataUri();

        assertTrue(LibString.startsWith(metadataDataUri, "data:application/json;base64,"), "Should have JSON prefix");

        string memory expectedDataUri =
            string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(metadata))));
        assertEq(metadataDataUri, expectedDataUri, "Metadata data URI should match");
    }

    function test_getMetadata_returnsValidJson() public view {
        string memory metadata = rendererV2.getMetadata();

        assertTrue(LibString.startsWith(metadata, "{"), "Should start with opening brace");
        assertTrue(LibString.endsWith(metadata, "}"), "Should end with closing brace");
        assertTrue(LibString.contains(metadata, '"name"'), "Should contain name field");
        assertTrue(LibString.contains(metadata, '"description"'), "Should contain description field");
        assertTrue(LibString.contains(metadata, '"image"'), "Should contain image field");
        assertTrue(LibString.contains(metadata, "PUSH4"), "Should contain PUSH4 name");
    }

    /*//////////////////////////////////////////////////////////////
                       OWNER-ONLY SETTER TESTS
      //////////////////////////////////////////////////////////////*/

    function test_setWidth_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        rendererV2.setWidth(20);
    }

    function test_setWidth_updatesState() public {
        rendererV2.setWidth(20);
        assertEq(rendererV2.width(), 20);
    }

    function test_setHeight_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        rendererV2.setHeight(30);
    }

    function test_setHeight_updatesState() public {
        rendererV2.setHeight(30);
        assertEq(rendererV2.height(), 30);
    }

    function test_setPixelSize_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        rendererV2.setPixelSize(10);
    }

    function test_setPixelSize_updatesState() public {
        rendererV2.setPixelSize(10);
        assertEq(rendererV2.pixelSize(), 10);
    }

    function test_setPush4Core_revertsWhenNotOwner() public {
        PUSH4Core newCore = new PUSH4Core(address(push4), owner);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        rendererV2.setPush4Core(newCore);
    }

    function test_setPush4Core_updatesState() public {
        PUSH4Core newCore = new PUSH4Core(address(push4), owner);
        rendererV2.setPush4Core(newCore);
        assertEq(address(rendererV2.push4Core()), address(newCore));
    }

    function test_setMetadata_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        rendererV2.setMetadata("new metadata");
    }

    /*//////////////////////////////////////////////////////////////
                           EXECUTED MODE TESTS
      //////////////////////////////////////////////////////////////*/

    function test_getPixels_executedMode_returnsTransformedPixels() public {
        push4Core.mint(tokenOwner);
        vm.startPrank(tokenOwner);
        push4Core.setProxy(address(proxyTemplate));
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        vm.stopPrank();

        bytes4[] memory carvedPixels = rendererV2.getPixels(IPUSH4Core.Mode.Carved);
        bytes4[] memory executedPixels = rendererV2.getPixels(IPUSH4Core.Mode.Executed);

        assertEq(executedPixels.length, TOTAL_PIXELS, "Should return 375 pixels");

        for (uint256 i = 0; i < TOTAL_PIXELS; i++) {
            bytes4 expected = proxyTemplate.execute(carvedPixels[i]);
            assertEq(
                executedPixels[i],
                expected,
                string(abi.encodePacked("Executed pixel mismatch at index ", LibString.toString(i)))
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                          KNOWN FALSE SELECTOR TESTS
      //////////////////////////////////////////////////////////////*/

    function test_isKnownFalseSelector_returnsTrueForAllKnownSelectors() public view {
        bytes4[11] memory falseSelectors = rendererV2.getKnownFalseSelectors();

        for (uint256 i = 0; i < falseSelectors.length; i++) {
            assertTrue(
                rendererV2.isKnownFalseSelector(falseSelectors[i]),
                string(abi.encodePacked("Selector at index ", LibString.toString(i), " should be known false"))
            );
        }
    }
}
