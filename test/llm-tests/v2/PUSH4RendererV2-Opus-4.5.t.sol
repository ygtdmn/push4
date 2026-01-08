// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";
import { PUSH4RendererV2 } from "../../../src/PUSH4RendererV2.sol";
import { IPUSH4RendererV2 } from "../../../src/interface/IPUSH4RendererV2.sol";
import { PUSH4Core, IPUSH4Core } from "../../../src/PUSH4Core.sol";
import { PUSH4 } from "../../../src/PUSH4.sol";
import { IMURIProtocol } from "../../../src/interface/IMURIProtocol.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";
import { MockPUSH4Proxy } from "../../mocks/MockPUSH4Proxy.sol";

/// @notice Extended mock for MURI Protocol with renderRawHTML support
contract MockMURIProtocolV2 is IMURIProtocol {
    mapping(address => mapping(uint256 => string)) private _combinedUris;
    mapping(address => mapping(uint256 => string)) private _rawHtml;
    bool public initializeCalled;

    function setCombinedArtworkUris(address contractAddress, uint256 tokenId, string memory uris) external {
        _combinedUris[contractAddress][tokenId] = uris;
    }

    function setRawHTML(address contractAddress, uint256 tokenId, string memory html) external {
        _rawHtml[contractAddress][tokenId] = html;
    }

    function getCombinedArtworkUris(address contractAddress, uint256 tokenId) external view returns (string memory) {
        return _combinedUris[contractAddress][tokenId];
    }

    function renderRawHTML(address contractAddress, uint256 tokenId) external view returns (string memory) {
        string memory html = _rawHtml[contractAddress][tokenId];
        if (bytes(html).length == 0) {
            return "<html><body>Block: {{BLOCK_INTERVAL}}, Core: {{CORE_ADDRESS}}, Token: {{TOKEN_ID}}</body></html>";
        }
        return html;
    }

    function initializeTokenData(address, uint256, InitConfig calldata, bytes[] calldata, string[] calldata) external {
        initializeCalled = true;
    }

    function registerContract(address, address) external override { }

    function isContractOperator(address, address) external pure override returns (bool) {
        return true;
    }
    function updateMetadata(address, uint256, string calldata) external override { }
    function updateHtmlTemplate(address, uint256, string[] calldata, bool) external override { }
    function updateThumbnail(address, uint256, Thumbnail calldata, bytes[] calldata) external override { }
    function revokeArtistPermissions(address, uint256, bool, bool, bool, bool, bool, bool, bool) external override { }
    function revokeAllArtistPermissions(address, uint256) external override { }
    function addArtworkUris(address, uint256, string[] calldata) external override { }
    function removeArtworkUris(address, uint256, uint256[] calldata) external override { }
    function setSelectedUri(address, uint256, uint256) external override { }
    function setSelectedThumbnailUri(address, uint256, uint256) external override { }
    function setDisplayMode(address, uint256, DisplayMode) external override { }
    function setDefaultHtmlTemplate(string[] calldata, bool) external override { }

    function getDefaultHtmlTemplate() external pure override returns (string memory) {
        return "";
    }

    function renderImage(address, uint256) external pure override returns (string memory) {
        return "";
    }

    function renderRawImage(address, uint256) external pure override returns (bytes memory) {
        return "";
    }

    function renderHTML(address, uint256) external pure override returns (string memory) {
        return "";
    }

    function renderMetadata(address, uint256) external pure override returns (string memory) {
        return "";
    }

    function getArtistArtworkUris(address, uint256) external pure override returns (string[] memory) {
        return new string[](0);
    }

    function getCollectorArtworkUris(address, uint256) external pure override returns (string[] memory) {
        return new string[](0);
    }

    function getThumbnailUris(address, uint256) external pure override returns (string[] memory) {
        return new string[](0);
    }

    function getPermissions(address, uint256) external pure override returns (Permissions memory) {
        return Permissions(0);
    }

    function getArtwork(address, uint256) external pure override returns (Artwork memory) {
        return Artwork(new string[](0), new string[](0), "", "", false, 0);
    }

    function getThumbnailInfo(address, uint256) external pure override returns (ThumbnailKind, uint256) {
        return (ThumbnailKind.OFF_CHAIN, 0);
    }

    function getTokenHtmlTemplate(address, uint256) external pure override returns (string memory) {
        return "";
    }
}

contract PUSH4RendererV2Opus45Test is Test {
    PUSH4RendererV2 public rendererV2;
    PUSH4Core public push4Core;
    PUSH4 public push4;
    MockMURIProtocolV2 public mockMuri;

    address public owner = address(this);
    address public alice = makeAddr("alice");
    address public tokenOwner = makeAddr("tokenOwner");

    uint256 constant WIDTH = 15;
    uint256 constant HEIGHT = 25;
    uint256 constant PIXEL_SIZE = 20;
    uint256 constant BLOCK_INTERVAL = 100;

    string constant METADATA = unicode"\"name\": \"PUSH4 V2\",\"description\": \"V2 test\"";

    // Deterministic addresses
    address constant PUSH4_ADDRESS = 0x000000630bf663df3ff850DD34a28Fb7D4d52170;
    address constant PUSH4_CORE_ADDRESS = 0x00000063266aAAeDD489e4956153855626E44061;

    event BlockIntervalUpdated(uint256 oldValue, uint256 newValue);
    event MURIProtocolUpdated(address indexed muriProtocol);

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
        push4Core.setRenderer(rendererV2);

        // Deploy mock MURI
        mockMuri = new MockMURIProtocolV2();
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsWidthCorrectly() public view {
        assertEq(rendererV2.width(), WIDTH);
    }

    function test_constructor_setsHeightCorrectly() public view {
        assertEq(rendererV2.height(), HEIGHT);
    }

    function test_constructor_setsPixelSizeCorrectly() public view {
        assertEq(rendererV2.pixelSize(), PIXEL_SIZE);
    }

    function test_constructor_setsPush4CoreCorrectly() public view {
        assertEq(address(rendererV2.push4Core()), address(push4Core));
    }

    function test_constructor_setsBlockIntervalCorrectly() public view {
        assertEq(rendererV2.blockInterval(), BLOCK_INTERVAL);
    }

    function test_constructor_setsOwnerCorrectly() public view {
        assertEq(rendererV2.owner(), owner);
    }

    function test_constructor_muriProtocolIsZeroByDefault() public view {
        assertEq(address(rendererV2.muriProtocol()), address(0));
    }

    function test_constructor_revertsWhenBlockIntervalIsZero() public {
        vm.expectRevert(IPUSH4RendererV2.InvalidBlockInterval.selector);
        new PUSH4RendererV2(WIDTH, HEIGHT, PIXEL_SIZE, push4Core, METADATA, 0, owner);
    }

    function test_constructor_TOKEN_ID_isZero() public view {
        assertEq(rendererV2.TOKEN_ID(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            SET BLOCK INTERVAL
    //////////////////////////////////////////////////////////////*/

    function test_setBlockInterval_updatesValue() public {
        uint256 newInterval = 200;
        rendererV2.setBlockInterval(newInterval);
        assertEq(rendererV2.blockInterval(), newInterval);
    }

    function test_setBlockInterval_emitsEvent() public {
        uint256 newInterval = 200;
        vm.expectEmit(true, true, true, true);
        emit BlockIntervalUpdated(BLOCK_INTERVAL, newInterval);
        rendererV2.setBlockInterval(newInterval);
    }

    function test_setBlockInterval_revertsWhenZero() public {
        vm.expectRevert(IPUSH4RendererV2.InvalidBlockInterval.selector);
        rendererV2.setBlockInterval(0);
    }

    function test_setBlockInterval_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        rendererV2.setBlockInterval(200);
    }

    /*//////////////////////////////////////////////////////////////
                           SET MURI PROTOCOL
    //////////////////////////////////////////////////////////////*/

    function test_setMURIProtocol_updatesAddress() public {
        rendererV2.setMURIProtocol(address(mockMuri));
        assertEq(address(rendererV2.muriProtocol()), address(mockMuri));
    }

    function test_setMURIProtocol_emitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit MURIProtocolUpdated(address(mockMuri));
        rendererV2.setMURIProtocol(address(mockMuri));
    }

    function test_setMURIProtocol_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        rendererV2.setMURIProtocol(address(mockMuri));
    }

    function test_setMURIProtocol_allowsSettingToZero() public {
        rendererV2.setMURIProtocol(address(mockMuri));
        rendererV2.setMURIProtocol(address(0));
        assertEq(address(rendererV2.muriProtocol()), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                            GET ANIMATION URL
    //////////////////////////////////////////////////////////////*/

    function test_getAnimationUrl_returnsEmptyWhenNoMuri() public view {
        string memory animUrl = rendererV2.getAnimationUrl();
        assertEq(animUrl, "");
    }

    function test_getAnimationUrl_returnsBase64EncodedHtml() public {
        rendererV2.setMURIProtocol(address(mockMuri));
        string memory animUrl = rendererV2.getAnimationUrl();

        // Should start with data:text/html;base64,
        assertTrue(_startsWith(animUrl, "data:text/html;base64,"), "Should be base64 HTML data URI");
    }

    function test_getAnimationUrl_replacesBlockInterval() public {
        rendererV2.setMURIProtocol(address(mockMuri));
        string memory animUrl = rendererV2.getAnimationUrl();

        // Decode the base64 content
        bytes memory animUrlBytes = bytes(animUrl);
        uint256 prefixLength = 22; // "data:text/html;base64,".length
        bytes memory base64Part = new bytes(animUrlBytes.length - prefixLength);
        for (uint256 i = prefixLength; i < animUrlBytes.length; i++) {
            base64Part[i - prefixLength] = animUrlBytes[i];
        }
        bytes memory decoded = Base64.decode(string(base64Part));
        string memory html = string(decoded);

        // Should contain the replaced block interval
        assertTrue(_contains(html, LibString.toString(BLOCK_INTERVAL)), "Should contain block interval value");
        assertFalse(_contains(html, "{{BLOCK_INTERVAL}}"), "Template variable should be replaced");
    }

    function test_getAnimationUrl_replacesCoreAddress() public {
        rendererV2.setMURIProtocol(address(mockMuri));
        string memory animUrl = rendererV2.getAnimationUrl();

        // Decode and verify core address replacement
        bytes memory animUrlBytes = bytes(animUrl);
        uint256 prefixLength = 22;
        bytes memory base64Part = new bytes(animUrlBytes.length - prefixLength);
        for (uint256 i = prefixLength; i < animUrlBytes.length; i++) {
            base64Part[i - prefixLength] = animUrlBytes[i];
        }
        bytes memory decoded = Base64.decode(string(base64Part));
        string memory html = string(decoded);

        assertFalse(_contains(html, "{{CORE_ADDRESS}}"), "Core address template should be replaced");
    }

    function test_getAnimationUrl_replacesTokenId() public {
        rendererV2.setMURIProtocol(address(mockMuri));
        string memory animUrl = rendererV2.getAnimationUrl();

        // Decode and verify token ID replacement
        bytes memory animUrlBytes = bytes(animUrl);
        uint256 prefixLength = 22;
        bytes memory base64Part = new bytes(animUrlBytes.length - prefixLength);
        for (uint256 i = prefixLength; i < animUrlBytes.length; i++) {
            base64Part[i - prefixLength] = animUrlBytes[i];
        }
        bytes memory decoded = Base64.decode(string(base64Part));
        string memory html = string(decoded);

        assertFalse(_contains(html, "{{TOKEN_ID}}"), "Token ID template should be replaced");
    }

    /*//////////////////////////////////////////////////////////////
                              GET METADATA
    //////////////////////////////////////////////////////////////*/

    function test_getMetadata_carvedMode_noAnimationUrl() public view {
        // Default mode is Carved
        string memory metadata = rendererV2.getMetadata();

        // Should not contain animation_url in Carved mode
        assertFalse(_contains(metadata, "animation_url"), "Carved mode should not have animation_url");
    }

    function test_getMetadata_executedMode_includesAnimationUrl() public {
        push4Core.mint(tokenOwner);

        // Deploy a real mock proxy (needs to be a contract, not just an address)
        MockPUSH4Proxy mockProxy = new MockPUSH4Proxy("Test Proxy", "Test Description", "Test Creator", tokenOwner);

        // Set mode to Executed and set a proxy (required for Executed mode to work)
        vm.startPrank(tokenOwner);
        push4Core.setProxy(address(mockProxy));
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        vm.stopPrank();

        // Set MURI protocol
        rendererV2.setMURIProtocol(address(mockMuri));

        string memory metadata = rendererV2.getMetadata();

        // Should contain animation_url in Executed mode
        assertTrue(_contains(metadata, "animation_url"), "Executed mode should have animation_url");
    }

    function test_getMetadata_containsImage() public view {
        string memory metadata = rendererV2.getMetadata();
        assertTrue(_contains(metadata, '"image":'), "Metadata should contain image");
    }

    function test_getMetadata_containsName() public view {
        string memory metadata = rendererV2.getMetadata();
        assertTrue(_contains(metadata, '"name": "PUSH4 V2"'), "Metadata should contain name");
    }

    /*//////////////////////////////////////////////////////////////
                            INHERITED V1 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_getSvg_startsWithSvgTag() public view {
        string memory svg = rendererV2.getSvg();
        assertTrue(_startsWith(svg, '<svg xmlns="http://www.w3.org/2000/svg"'), "SVG should start with svg tag");
    }

    function test_getSvg_endsWithClosingSvgTag() public view {
        string memory svg = rendererV2.getSvg();
        assertTrue(_endsWith(svg, "</svg>"), "SVG should end with closing svg tag");
    }

    function test_getSvgDataUri_startsWithCorrectPrefix() public view {
        string memory dataUri = rendererV2.getSvgDataUri();
        assertTrue(_startsWith(dataUri, "data:image/svg+xml;base64,"), "Data URI should start with correct prefix");
    }

    function test_getMetadataDataUri_startsWithCorrectPrefix() public view {
        string memory dataUri = rendererV2.getMetadataDataUri();
        assertTrue(_startsWith(dataUri, "data:application/json;base64,"), "Data URI should start with correct prefix");
    }

    function test_getPixels_carvedMode_returnsCorrectLength() public view {
        bytes4[] memory pixels = rendererV2.getPixels(IPUSH4Core.Mode.Carved);
        assertEq(pixels.length, WIDTH * HEIGHT);
    }

    function test_getKnownFalseSelectors_returns11Selectors() public view {
        bytes4[11] memory selectors = rendererV2.getKnownFalseSelectors();
        assertEq(selectors.length, 11);
    }

    /*//////////////////////////////////////////////////////////////
                              V1 SETTERS
    //////////////////////////////////////////////////////////////*/

    function test_setWidth_updatesValue() public {
        uint256 newWidth = 20;
        rendererV2.setWidth(newWidth);
        assertEq(rendererV2.width(), newWidth);
    }

    function test_setWidth_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        rendererV2.setWidth(20);
    }

    function test_setHeight_updatesValue() public {
        uint256 newHeight = 30;
        rendererV2.setHeight(newHeight);
        assertEq(rendererV2.height(), newHeight);
    }

    function test_setHeight_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        rendererV2.setHeight(30);
    }

    function test_setPixelSize_updatesValue() public {
        uint256 newPixelSize = 30;
        rendererV2.setPixelSize(newPixelSize);
        assertEq(rendererV2.pixelSize(), newPixelSize);
    }

    function test_setPixelSize_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        rendererV2.setPixelSize(30);
    }

    function test_setPush4Core_updatesValue() public {
        IPUSH4Core newCore = IPUSH4Core(makeAddr("newCore"));
        rendererV2.setPush4Core(newCore);
        assertEq(address(rendererV2.push4Core()), address(newCore));
    }

    function test_setPush4Core_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        rendererV2.setPush4Core(IPUSH4Core(makeAddr("newCore")));
    }

    function test_setMetadata_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        rendererV2.setMetadata("new metadata");
    }

    /*//////////////////////////////////////////////////////////////
                           HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory prefixBytes = bytes(prefix);

        if (prefixBytes.length > strBytes.length) {
            return false;
        }

        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (strBytes[i] != prefixBytes[i]) {
                return false;
            }
        }
        return true;
    }

    function _endsWith(string memory str, string memory suffix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory suffixBytes = bytes(suffix);

        if (suffixBytes.length > strBytes.length) {
            return false;
        }

        uint256 offset = strBytes.length - suffixBytes.length;
        for (uint256 i = 0; i < suffixBytes.length; i++) {
            if (strBytes[offset + i] != suffixBytes[i]) {
                return false;
            }
        }
        return true;
    }

    function _contains(string memory str, string memory substr) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory substrBytes = bytes(substr);

        if (substrBytes.length > strBytes.length) {
            return false;
        }

        for (uint256 i = 0; i <= strBytes.length - substrBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < substrBytes.length; j++) {
                if (strBytes[i + j] != substrBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return true;
            }
        }
        return false;
    }
}

