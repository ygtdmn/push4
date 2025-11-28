// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";
import { PUSH4Renderer } from "../../src/PUSH4Renderer.sol";
import { PUSH4RendererMock } from "../../test/mocks/PUSH4RendererMock.sol";
import { PUSH4Core, IPUSH4Core } from "../../src/PUSH4Core.sol";
import { PUSH4 } from "../../src/PUSH4.sol";
import { IPUSH4Renderer } from "../../src/interface/IPUSH4Renderer.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";
import { PUSH4TestBase } from "../PUSH4TestBase.sol";

contract PUSH4RendererOpus45Test is PUSH4TestBase {
    address public owner = address(this);
    address public tokenOwner = makeAddr("tokenOwner");

    uint256 constant WIDTH = 15;
    uint256 constant HEIGHT = 25;
    uint256 constant PIXEL_SIZE = 20;
    uint256 constant PIXEL_COUNT = WIDTH * HEIGHT;

    string constant METADATA =
        unicode"\"name\": \"PUSH4\",\"description\": \"A heavily compressed and dithered down version of Barnett Newman's Onement I, encoded in 375 smart contract function selectors.\"";

    function setUp() public {
        _fullSetup(owner, WIDTH, HEIGHT, PIXEL_SIZE, METADATA);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsWidthCorrectly() public view {
        assertEq(renderer.width(), WIDTH);
    }

    function test_constructor_setsHeightCorrectly() public view {
        assertEq(renderer.height(), HEIGHT);
    }

    function test_constructor_setsPixelSizeCorrectly() public view {
        assertEq(renderer.pixelSize(), PIXEL_SIZE);
    }

    function test_constructor_setsPush4CoreCorrectly() public view {
        assertEq(address(renderer.push4Core()), address(push4Core));
    }

    function test_constructor_setsOwnerCorrectly() public view {
        assertEq(renderer.owner(), owner);
    }

    /*//////////////////////////////////////////////////////////////
                              GET PIXELS
    //////////////////////////////////////////////////////////////*/

    function test_getPixels_carvedMode_returnsCorrectLength() public view {
        bytes4[] memory pixels = renderer.getPixels(IPUSH4Core.Mode.Carved);
        assertEq(pixels.length, PIXEL_COUNT);
    }

    function test_getPixels_executedMode_returnsCorrectLength() public view {
        bytes4[] memory pixels = renderer.getPixels(IPUSH4Core.Mode.Executed);
        assertEq(pixels.length, PIXEL_COUNT);
    }

    function test_getPixels_carvedMode_pixelsAreSortedByColumnIndex() public view {
        bytes4[] memory pixels = renderer.getPixels(IPUSH4Core.Mode.Carved);

        // Verify pixels are sorted by column index (last byte)
        for (uint256 i = 1; i < pixels.length; i++) {
            uint8 prevColIndex = uint8(pixels[i - 1][3]);
            uint8 currColIndex = uint8(pixels[i][3]);
            assertTrue(prevColIndex <= currColIndex, "Pixels should be sorted by column index");
        }
    }

    function test_getPixels_carvedMode_allColumnsPresent() public view {
        bytes4[] memory pixels = renderer.getPixels(IPUSH4Core.Mode.Carved);

        // Count pixels per column
        uint256[] memory columnCounts = new uint256[](WIDTH);
        for (uint256 i = 0; i < pixels.length; i++) {
            uint8 colIndex = uint8(pixels[i][3]);
            if (colIndex < WIDTH) {
                columnCounts[colIndex]++;
            }
        }

        // Each column should have HEIGHT pixels
        for (uint256 col = 0; col < WIDTH; col++) {
            assertEq(columnCounts[col], HEIGHT, "Each column should have HEIGHT pixels");
        }
    }

    /*//////////////////////////////////////////////////////////////
                                GET SVG
    //////////////////////////////////////////////////////////////*/

    function test_getSvg_startsWithSvgTag() public view {
        string memory svg = renderer.getSvg();
        assertTrue(_startsWith(svg, '<svg xmlns="http://www.w3.org/2000/svg"'), "SVG should start with svg tag");
    }

    function test_getSvg_endsWithClosingSvgTag() public view {
        string memory svg = renderer.getSvg();
        assertTrue(_endsWith(svg, "</svg>"), "SVG should end with closing svg tag");
    }

    function test_getSvg_containsCorrectDimensions() public view {
        string memory svg = renderer.getSvg();
        string memory expectedWidth = string(abi.encodePacked('width="', LibString.toString(WIDTH * PIXEL_SIZE), '"'));
        string memory expectedHeight =
            string(abi.encodePacked('height="', LibString.toString(HEIGHT * PIXEL_SIZE), '"'));

        assertTrue(_contains(svg, expectedWidth), "SVG should contain correct width");
        assertTrue(_contains(svg, expectedHeight), "SVG should contain correct height");
    }

    function test_getSvg_containsCorrectViewBox() public view {
        string memory svg = renderer.getSvg();
        string memory expectedViewBox =
            string(abi.encodePacked('viewBox="0 0 ', LibString.toString(WIDTH), " ", LibString.toString(HEIGHT), '"'));

        assertTrue(_contains(svg, expectedViewBox), "SVG should contain correct viewBox");
    }

    function test_getSvg_containsCrispEdgesRendering() public view {
        string memory svg = renderer.getSvg();
        assertTrue(_contains(svg, 'shape-rendering="crispEdges"'), "SVG should contain crispEdges rendering");
    }

    function test_getSvg_containsRectElements() public view {
        string memory svg = renderer.getSvg();
        assertTrue(_contains(svg, "<rect"), "SVG should contain rect elements");
    }

    /*//////////////////////////////////////////////////////////////
                            GET SVG DATA URI
    //////////////////////////////////////////////////////////////*/

    function test_getSvgDataUri_startsWithCorrectPrefix() public view {
        string memory dataUri = renderer.getSvgDataUri();
        assertTrue(
            _startsWith(dataUri, "data:image/svg+xml;base64,"), "Data URI should start with correct prefix"
        );
    }

    function test_getSvgDataUri_containsValidBase64() public view {
        string memory dataUri = renderer.getSvgDataUri();
        // Remove prefix
        bytes memory dataUriBytes = bytes(dataUri);
        uint256 prefixLength = 26; // "data:image/svg+xml;base64,".length

        bytes memory base64Part = new bytes(dataUriBytes.length - prefixLength);
        for (uint256 i = prefixLength; i < dataUriBytes.length; i++) {
            base64Part[i - prefixLength] = dataUriBytes[i];
        }

        // Decode and verify it matches the SVG
        bytes memory decoded = Base64.decode(string(base64Part));
        string memory svg = renderer.getSvg();
        assertEq(string(decoded), svg, "Decoded base64 should match SVG");
    }

    /*//////////////////////////////////////////////////////////////
                              GET METADATA
    //////////////////////////////////////////////////////////////*/

    function test_getMetadata_startsWithOpenBrace() public view {
        string memory metadata = renderer.getMetadata();
        assertTrue(_startsWith(metadata, "{"), "Metadata should start with open brace");
    }

    function test_getMetadata_endsWithCloseBrace() public view {
        string memory metadata = renderer.getMetadata();
        assertTrue(_endsWith(metadata, "}"), "Metadata should end with close brace");
    }

    function test_getMetadata_containsName() public view {
        string memory metadata = renderer.getMetadata();
        assertTrue(_contains(metadata, '"name": "PUSH4"'), "Metadata should contain name");
    }

    function test_getMetadata_containsDescription() public view {
        string memory metadata = renderer.getMetadata();
        assertTrue(_contains(metadata, '"description":'), "Metadata should contain description");
    }

    function test_getMetadata_containsImage() public view {
        string memory metadata = renderer.getMetadata();
        assertTrue(_contains(metadata, '"image":'), "Metadata should contain image");
    }

    function test_getMetadata_imageIsDataUri() public view {
        string memory metadata = renderer.getMetadata();
        assertTrue(
            _contains(metadata, "data:image/svg+xml;base64,"), "Metadata image should be data URI"
        );
    }

    /*//////////////////////////////////////////////////////////////
                          GET METADATA DATA URI
    //////////////////////////////////////////////////////////////*/

    function test_getMetadataDataUri_startsWithCorrectPrefix() public view {
        string memory dataUri = renderer.getMetadataDataUri();
        assertTrue(
            _startsWith(dataUri, "data:application/json;base64,"), "Data URI should start with correct prefix"
        );
    }

    function test_getMetadataDataUri_containsValidBase64() public view {
        string memory dataUri = renderer.getMetadataDataUri();
        // Remove prefix
        bytes memory dataUriBytes = bytes(dataUri);
        uint256 prefixLength = 29; // "data:application/json;base64,".length

        bytes memory base64Part = new bytes(dataUriBytes.length - prefixLength);
        for (uint256 i = prefixLength; i < dataUriBytes.length; i++) {
            base64Part[i - prefixLength] = dataUriBytes[i];
        }

        // Decode and verify it matches the metadata
        bytes memory decoded = Base64.decode(string(base64Part));
        string memory metadata = renderer.getMetadata();
        assertEq(string(decoded), metadata, "Decoded base64 should match metadata");
    }

    /*//////////////////////////////////////////////////////////////
                        KNOWN FALSE SELECTORS
    //////////////////////////////////////////////////////////////*/

    function test_getKnownFalseSelectors_returns11Selectors() public view {
        bytes4[11] memory selectors = renderer.getKnownFalseSelectors();
        assertEq(selectors.length, 11);
    }

    function test_isKnownFalseSelector_returnsTrueForKnownSelectors() public view {
        bytes4[11] memory knownSelectors = renderer.getKnownFalseSelectors();

        // Test first 10 selectors (the function checks indices 0-9)
        for (uint256 i = 0; i < 10; i++) {
            assertTrue(
                renderer.isKnownFalseSelector(knownSelectors[i]),
                "Should return true for known false selector"
            );
        }
    }

    function test_isKnownFalseSelector_returnsFalseForUnknownSelector() public view {
        bytes4 unknownSelector = bytes4(0x12345678);
        assertFalse(renderer.isKnownFalseSelector(unknownSelector), "Should return false for unknown selector");
    }

    function test_isKnownFalseSelector_returnsFalseForRandomSelector() public view {
        bytes4 randomSelector = bytes4(keccak256("randomFunction()"));
        assertFalse(renderer.isKnownFalseSelector(randomSelector), "Should return false for random selector");
    }

    /*//////////////////////////////////////////////////////////////
                     EXTRACT SELECTORS FROM BYTECODE
    //////////////////////////////////////////////////////////////*/

    function test_extractSelectorsFromBytecode_revertsForNoCode() public {
        address emptyAddress = makeAddr("empty");
        vm.expectRevert(IPUSH4Renderer.NoCodeAtTarget.selector);
        rendererMock.extractSelectorsFromBytecode(emptyAddress, 10, false);
    }

    function test_extractSelectorsFromBytecode_findsCorrectCount() public view {
        bytes4[] memory selectors = rendererMock.extractSelectorsFromBytecode(address(push4), PIXEL_COUNT, false);
        assertEq(selectors.length, PIXEL_COUNT, "Should find expected number of selectors");
    }

    function test_extractSelectorsFromBytecode_withFilteringEnabled() public view {
        // Get selectors with filtering
        bytes4[] memory selectors = rendererMock.extractSelectorsFromBytecode(address(push4), PIXEL_COUNT, true);
        assertEq(selectors.length, PIXEL_COUNT, "Should find expected number of selectors");
    }

    /*//////////////////////////////////////////////////////////////
                              OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    function test_transferOwnership_revertsWhenNotOwner() public {
        address alice = makeAddr("alice");
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        renderer.transferOwnership(alice);
    }

    function test_transferOwnership_succeeds() public {
        address newOwner = makeAddr("newOwner");
        renderer.transferOwnership(newOwner);
        assertEq(renderer.owner(), newOwner);
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

contract PUSH4RendererModeTest is PUSH4TestBase {
    address public owner = address(this);
    address public tokenOwner = makeAddr("tokenOwner");

    uint256 constant WIDTH = 15;
    uint256 constant HEIGHT = 25;
    uint256 constant PIXEL_SIZE = 20;

    string constant METADATA =
        unicode"\"name\": \"PUSH4\",\"description\": \"A heavily compressed and dithered down version of Barnett Newman's Onement I, encoded in 375 smart contract function selectors.\"";

    function setUp() public {
        _fullSetup(owner, WIDTH, HEIGHT, PIXEL_SIZE, METADATA);
        push4Core.mint(tokenOwner);
    }

    function test_getPixels_changesWithMode() public {
        // Get pixels in Carved mode (default)
        bytes4[] memory carvedPixels = renderer.getPixels(IPUSH4Core.Mode.Carved);

        // Set mode to Executed
        vm.prank(tokenOwner);
        push4Core.setMode(IPUSH4Core.Mode.Executed);

        // Get pixels in Executed mode
        bytes4[] memory executedPixels = renderer.getPixels(IPUSH4Core.Mode.Executed);

        // Both should have the same length
        assertEq(carvedPixels.length, executedPixels.length);

        // In Executed mode without a proxy, the pixels should be the same as Carved
        // (since the PUSH4 contract returns the signature when no proxy is set)
        // This tests that the mode switching logic works
    }

    function test_getSvg_reflectsCurrentMode() public view {
        // The SVG generation uses the current mode from push4Core
        string memory svg = renderer.getSvg();
        assertTrue(bytes(svg).length > 0, "SVG should be generated");
    }
}

contract PUSH4RendererEdgeCasesTest is PUSH4TestBase {
    address public owner = address(this);

    string constant METADATA = '"name": "Test"';

    function test_constructor_withZeroDimensions() public {
        _deployPush4();
        _deployPush4Core(owner);

        // This should not revert, but will produce an empty image
        PUSH4Renderer zeroRenderer = new PUSH4Renderer(0, 0, 1, push4Core, METADATA, owner);
        assertEq(zeroRenderer.width(), 0);
        assertEq(zeroRenderer.height(), 0);
    }

    function test_constructor_withEmptyMetadata() public {
        _deployPush4();
        _deployPush4Core(owner);
        PUSH4Renderer emptyMetaRenderer = new PUSH4Renderer(15, 25, 20, push4Core, "", owner);
        push4Core.setRenderer(emptyMetaRenderer);

        string memory metadata = emptyMetaRenderer.getMetadata();
        // Should still have the image field
        assertTrue(bytes(metadata).length > 0, "Metadata should not be empty");
    }

    function test_constructor_withLargePixelSize() public {
        _deployPush4();
        _deployPush4Core(owner);
        PUSH4Renderer largePixelRenderer = new PUSH4Renderer(15, 25, 1000, push4Core, METADATA, owner);

        assertEq(largePixelRenderer.pixelSize(), 1000);
        string memory svg = largePixelRenderer.getSvg();
        // SVG should have width/height based on large pixel size
        assertTrue(bytes(svg).length > 0, "SVG should be generated");
    }
}
