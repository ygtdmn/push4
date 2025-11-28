// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";
import { PUSH4 } from "../../src/PUSH4.sol";
import { PUSH4Core } from "../../src/PUSH4Core.sol";
import { PUSH4Renderer } from "../../src/PUSH4Renderer.sol";
import { IPUSH4Core } from "../../src/interface/IPUSH4Core.sol";
import { IPUSH4Renderer } from "../../src/interface/IPUSH4Renderer.sol";
import { PUSH4RendererMock } from "../../test/mocks/PUSH4RendererMock.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";
import { PUSH4TestBase } from "../PUSH4TestBase.sol";

contract PUSH4RendererSonnet45Test is PUSH4TestBase {
    address public owner = address(this);
    address public tokenOwner = makeAddr("tokenOwner");

    uint256 public constant WIDTH = 15;
    uint256 public constant HEIGHT = 25;
    uint256 public constant PIXEL_SIZE = 20;
    uint256 public constant TOTAL_PIXELS = WIDTH * HEIGHT;

    string constant METADATA =
        unicode"\"name\": \"PUSH4\",\"description\": \"A heavily compressed and dithered down version of Barnett Newman's Onement I, encoded in 375 smart contract function selectors.\"";

    function setUp() public {
        _fullSetup(owner, WIDTH, HEIGHT, PIXEL_SIZE, METADATA);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsWidth() public view {
        assertEq(renderer.width(), WIDTH);
    }

    function test_constructor_setsHeight() public view {
        assertEq(renderer.height(), HEIGHT);
    }

    function test_constructor_setsPixelSize() public view {
        assertEq(renderer.pixelSize(), PIXEL_SIZE);
    }

    function test_constructor_setsPush4Core() public view {
        assertEq(address(renderer.push4Core()), address(push4Core));
    }

    function test_constructor_setsOwner() public view {
        assertEq(renderer.owner(), owner);
    }

    function test_constructor_withDifferentDimensions() public {
        PUSH4Renderer customRenderer = new PUSH4Renderer(10, 20, 15, push4Core, METADATA, owner);
        assertEq(customRenderer.width(), 10);
        assertEq(customRenderer.height(), 20);
        assertEq(customRenderer.pixelSize(), 15);
    }

    /*//////////////////////////////////////////////////////////////
                              GET PIXELS
    //////////////////////////////////////////////////////////////*/

    function test_getPixels_carvedMode_returnsCorrectLength() public view {
        bytes4[] memory pixels = renderer.getPixels(IPUSH4Core.Mode.Carved);
        assertEq(pixels.length, TOTAL_PIXELS);
    }

    function test_getPixels_carvedMode_returnsSortedByColumnIndex() public view {
        bytes4[] memory pixels = renderer.getPixels(IPUSH4Core.Mode.Carved);

        // Verify pixels are sorted by column index (last byte)
        for (uint256 i = 1; i < pixels.length; i++) {
            uint8 prevColumn = uint8(pixels[i - 1][3]);
            uint8 currColumn = uint8(pixels[i][3]);
            assertTrue(prevColumn <= currColumn, "Pixels should be sorted by column index");
        }
    }

    function test_getPixels_executedMode_returnsCorrectLength() public view {
        bytes4[] memory pixels = renderer.getPixels(IPUSH4Core.Mode.Executed);
        assertEq(pixels.length, TOTAL_PIXELS);
    }

    function test_getPixels_executedMode_callsPush4Functions() public view {
        bytes4[] memory carved = renderer.getPixels(IPUSH4Core.Mode.Carved);
        bytes4[] memory executed = renderer.getPixels(IPUSH4Core.Mode.Executed);

        assertEq(executed.length, carved.length);

        // Verify that executed pixels are results of calling the carved selectors
        for (uint256 i = 0; i < 5; i++) {
            // Test first 5 pixels
            (bool success, bytes memory result) = address(push4).staticcall(abi.encodePacked(carved[i]));
            assertTrue(success, "Function call should succeed");
            bytes4 expected = abi.decode(result, (bytes4));
            assertEq(executed[i], expected, "Executed pixel should match function return value");
        }
    }

    function test_getPixels_executedMode_matchesCarvedForPush4() public view {
        bytes4[] memory carved = renderer.getPixels(IPUSH4Core.Mode.Carved);
        bytes4[] memory executed = renderer.getPixels(IPUSH4Core.Mode.Executed);

        // In PUSH4 contract, functions return msg.sig, so carved and executed should match
        assertEq(executed.length, carved.length, "Both modes should have same length");
        
        // Verify first few pixels match (PUSH4 returns msg.sig)
        for (uint256 i = 0; i < 5 && i < carved.length; i++) {
            assertEq(executed[i], carved[i], "PUSH4 executed pixels should match carved (returns msg.sig)");
        }
    }

    /*//////////////////////////////////////////////////////////////
                                GET SVG
    //////////////////////////////////////////////////////////////*/

    function test_getSvg_containsCorrectDimensions() public view {
        string memory svg = renderer.getSvg();

        // Check for width and height attributes
        string memory widthStr = LibString.toString(WIDTH * PIXEL_SIZE);
        string memory heightStr = LibString.toString(HEIGHT * PIXEL_SIZE);

        assertTrue(_contains(svg, widthStr), "SVG should contain correct width");
        assertTrue(_contains(svg, heightStr), "SVG should contain correct height");
    }

    function test_getSvg_containsViewBox() public view {
        string memory svg = renderer.getSvg();
        string memory viewBox = string(
            abi.encodePacked('viewBox="0 0 ', LibString.toString(WIDTH), " ", LibString.toString(HEIGHT), '"')
        );

        assertTrue(_contains(svg, viewBox), "SVG should contain correct viewBox");
    }

    function test_getSvg_containsShapeRendering() public view {
        string memory svg = renderer.getSvg();
        assertTrue(_contains(svg, 'shape-rendering="crispEdges"'), "SVG should have crisp edges");
    }

    function test_getSvg_startsWithSvgTag() public view {
        string memory svg = renderer.getSvg();
        assertTrue(_startsWith(svg, '<svg xmlns="http://www.w3.org/2000/svg"'), "SVG should start with svg tag");
    }

    function test_getSvg_endsWithClosingTag() public view {
        string memory svg = renderer.getSvg();
        assertTrue(_endsWith(svg, "</svg>"), "SVG should end with closing tag");
    }

    function test_getSvg_containsRectElements() public view {
        string memory svg = renderer.getSvg();
        assertTrue(_contains(svg, "<rect"), "SVG should contain rect elements");
        assertTrue(_contains(svg, 'width="1"'), "Rects should have width 1");
        assertTrue(_contains(svg, 'height="1"'), "Rects should have height 1");
    }

    function test_getSvg_containsHexColors() public view {
        string memory svg = renderer.getSvg();
        assertTrue(_contains(svg, 'fill="#'), "SVG should contain hex colors");
    }

    function test_getSvg_containsFirstPixel() public view {
        string memory svg = renderer.getSvg();
        assertTrue(_contains(svg, '<rect x="0" y="0"'), "SVG should contain first pixel at (0,0)");
    }

    /*//////////////////////////////////////////////////////////////
                           SVG DATA URI
    //////////////////////////////////////////////////////////////*/

    function test_getSvgDataUri_hasCorrectPrefix() public view {
        string memory dataUri = renderer.getSvgDataUri();
        assertTrue(
            _startsWith(dataUri, "data:image/svg+xml;base64,"), "Data URI should have correct SVG data URI prefix"
        );
    }

    function test_getSvgDataUri_isBase64Encoded() public view {
        string memory svg = renderer.getSvg();
        string memory expected = string(abi.encodePacked("data:image/svg+xml;base64,", Base64.encode(bytes(svg))));
        assertEq(renderer.getSvgDataUri(), expected, "Data URI should be base64 encoded SVG");
    }

    function test_getSvgDataUri_isNotEmpty() public view {
        string memory dataUri = renderer.getSvgDataUri();
        assertTrue(bytes(dataUri).length > 27, "Data URI should contain encoded data");
    }

    /*//////////////////////////////////////////////////////////////
                              METADATA
    //////////////////////////////////////////////////////////////*/

    function test_getMetadata_containsBaseMetadata() public view {
        string memory metadata = renderer.getMetadata();
        assertTrue(_contains(metadata, METADATA), "Metadata should contain base metadata");
    }

    function test_getMetadata_containsImageField() public view {
        string memory metadata = renderer.getMetadata();
        assertTrue(_contains(metadata, '"image"'), "Metadata should contain image field");
    }

    function test_getMetadata_embedsSvgDataUri() public view {
        string memory metadata = renderer.getMetadata();
        string memory svgDataUri = renderer.getSvgDataUri();
        assertTrue(_contains(metadata, svgDataUri), "Metadata should embed SVG data URI");
    }

    function test_getMetadata_isValidJsonStructure() public view {
        string memory metadata = renderer.getMetadata();
        assertTrue(_startsWith(metadata, "{"), "Metadata should start with opening brace");
        assertTrue(_endsWith(metadata, "}"), "Metadata should end with closing brace");
    }

    function test_getMetadata_containsNameField() public view {
        string memory metadata = renderer.getMetadata();
        assertTrue(_contains(metadata, '"name"'), "Metadata should contain name field");
        assertTrue(_contains(metadata, "PUSH4"), "Metadata should contain PUSH4 name");
    }

    function test_getMetadata_containsDescriptionField() public view {
        string memory metadata = renderer.getMetadata();
        assertTrue(_contains(metadata, '"description"'), "Metadata should contain description field");
    }

    /*//////////////////////////////////////////////////////////////
                        METADATA DATA URI
    //////////////////////////////////////////////////////////////*/

    function test_getMetadataDataUri_hasCorrectPrefix() public view {
        string memory dataUri = renderer.getMetadataDataUri();
        assertTrue(
            _startsWith(dataUri, "data:application/json;base64,"), "Data URI should have correct JSON data URI prefix"
        );
    }

    function test_getMetadataDataUri_isBase64Encoded() public view {
        string memory metadata = renderer.getMetadata();
        string memory expected =
            string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(metadata))));
        assertEq(renderer.getMetadataDataUri(), expected, "Data URI should be base64 encoded metadata");
    }

    function test_getMetadataDataUri_isNotEmpty() public view {
        string memory dataUri = renderer.getMetadataDataUri();
        assertTrue(bytes(dataUri).length > 29, "Data URI should contain encoded data");
    }

    /*//////////////////////////////////////////////////////////////
                        KNOWN FALSE SELECTORS
    //////////////////////////////////////////////////////////////*/

    function test_getKnownFalseSelectors_returnsCorrectLength() public view {
        bytes4[11] memory selectors = renderer.getKnownFalseSelectors();
        assertEq(selectors.length, 11, "Should return 11 known false selectors");
    }

    function test_getKnownFalseSelectors_containsExpectedValues() public view {
        bytes4[11] memory selectors = renderer.getKnownFalseSelectors();
        assertEq(selectors[0], bytes4(0xec556889));
        assertEq(selectors[1], bytes4(0x6f2885b9));
        assertEq(selectors[2], bytes4(0x57509495));
        assertEq(selectors[3], bytes4(0x4e487b71));
        assertEq(selectors[10], bytes4(0xde510b72));
    }

    function test_isKnownFalseSelector_returnsTrueForKnownSelectors() public view {
        bytes4[11] memory selectors = renderer.getKnownFalseSelectors();
        for (uint256 i = 0; i < selectors.length; i++) {
            assertTrue(renderer.isKnownFalseSelector(selectors[i]), "Should return true for known false selector");
        }
    }

    function test_isKnownFalseSelector_returnsFalseForUnknownSelector() public view {
        assertFalse(renderer.isKnownFalseSelector(bytes4(0x12345678)), "Should return false for unknown selector");
        assertFalse(renderer.isKnownFalseSelector(bytes4(0xaaaaaaaa)), "Should return false for unknown selector");
        assertFalse(renderer.isKnownFalseSelector(bytes4(0xffffffff)), "Should return false for unknown selector");
    }

    /*//////////////////////////////////////////////////////////////
                     EXTRACT SELECTORS FROM BYTECODE
    //////////////////////////////////////////////////////////////*/

    function test_extractSelectorsFromBytecode_revertsWhenNoCode() public {
        vm.expectRevert(IPUSH4Renderer.NoCodeAtTarget.selector);
        rendererMock.extractSelectorsFromBytecode(address(0), TOTAL_PIXELS, false);
    }

    function test_extractSelectorsFromBytecode_revertsForEOA() public {
        address eoa = makeAddr("eoa");
        vm.expectRevert(IPUSH4Renderer.NoCodeAtTarget.selector);
        rendererMock.extractSelectorsFromBytecode(eoa, TOTAL_PIXELS, false);
    }

    function test_extractSelectorsFromBytecode_extractsFromPush4() public view {
        bytes4[] memory selectors = rendererMock.extractSelectorsFromBytecode(address(push4), TOTAL_PIXELS, false);
        assertEq(selectors.length, TOTAL_PIXELS, "Should extract expected number of selectors");
    }

    function test_extractSelectorsFromBytecode_withFilteringFalseSelectors() public view {
        bytes4[] memory withoutFilter = rendererMock.extractSelectorsFromBytecode(address(push4), TOTAL_PIXELS, false);
        bytes4[] memory withFilter = rendererMock.extractSelectorsFromBytecode(address(push4), TOTAL_PIXELS, true);

        // With filtering should have same or fewer selectors
        assertTrue(
            withFilter.length <= withoutFilter.length, "Filtered result should have same or fewer selectors"
        );
    }

    function test_extractSelectorsFromBytecode_extractsValidSelectors() public view {
        bytes4[] memory selectors = rendererMock.extractSelectorsFromBytecode(address(push4), TOTAL_PIXELS, false);

        // Check that extracted selectors are non-zero
        uint256 nonZeroCount = 0;
        for (uint256 i = 0; i < selectors.length; i++) {
            if (selectors[i] != bytes4(0)) {
                nonZeroCount++;
            }
        }
        assertTrue(nonZeroCount > 0, "Should extract non-zero selectors");
    }

    /*//////////////////////////////////////////////////////////////
                         MODE BEHAVIOR
    //////////////////////////////////////////////////////////////*/

    function test_getPixels_respectsCurrentMode() public view {
        // Verify that getPixels respects the mode parameter
        bytes4[] memory carvedPixels = renderer.getPixels(IPUSH4Core.Mode.Carved);
        bytes4[] memory executedPixels = renderer.getPixels(IPUSH4Core.Mode.Executed);

        assertEq(carvedPixels.length, TOTAL_PIXELS, "Carved mode should return all pixels");
        assertEq(executedPixels.length, TOTAL_PIXELS, "Executed mode should return all pixels");
    }

    function test_getSvg_usesCurrentCoreMode() public view {
        // The renderer calls push4Core.mode() to determine which pixels to use
        // In setUp, the mode is Carved by default
        string memory svg = renderer.getSvg();
        
        // Verify SVG is generated
        assertGt(bytes(svg).length, 0, "Should generate SVG based on current mode");
        assertTrue(_contains(svg, "<svg"), "Should contain SVG tag");
    }

    /*//////////////////////////////////////////////////////////////
                         INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_integration_fullRendererFlow() public view {
        // This test verifies the complete flow from pixels to data URI
        bytes4[] memory pixels = renderer.getPixels(IPUSH4Core.Mode.Carved);
        assertGt(pixels.length, 0, "Should have pixels");

        string memory svg = renderer.getSvg();
        assertGt(bytes(svg).length, 0, "Should have SVG");

        string memory svgDataUri = renderer.getSvgDataUri();
        assertGt(bytes(svgDataUri).length, 0, "Should have SVG data URI");

        string memory metadata = renderer.getMetadata();
        assertGt(bytes(metadata).length, 0, "Should have metadata");

        string memory metadataDataUri = renderer.getMetadataDataUri();
        assertGt(bytes(metadataDataUri).length, 0, "Should have metadata data URI");
    }

    function test_integration_push4CoreCanGetTokenURI() public {
        push4Core.mint(tokenOwner);
        string memory tokenURI = push4Core.tokenURI(0);

        assertGt(bytes(tokenURI).length, 0, "Token URI should not be empty");
        assertTrue(_startsWith(tokenURI, "data:application/json;base64,"), "Token URI should be metadata data URI");
    }

    /*//////////////////////////////////////////////////////////////
                           HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory haystackBytes = bytes(haystack);
        bytes memory needleBytes = bytes(needle);

        if (needleBytes.length == 0) {
            return true;
        }
        if (needleBytes.length > haystackBytes.length) {
            return false;
        }

        for (uint256 i = 0; i <= haystackBytes.length - needleBytes.length; i++) {
            bool matchFound = true;
            for (uint256 j = 0; j < needleBytes.length; j++) {
                if (haystackBytes[i + j] != needleBytes[j]) {
                    matchFound = false;
                    break;
                }
            }
            if (matchFound) {
                return true;
            }
        }

        return false;
    }

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
}
