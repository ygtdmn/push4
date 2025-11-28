// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";
import { PUSH4 } from "../src/PUSH4.sol";
import { PUSH4Core } from "../src/PUSH4Core.sol";
import { PUSH4Renderer } from "../src/PUSH4Renderer.sol";
import { PUSH4ProxyTemplate } from "../src/PUSH4ProxyTemplate.sol";
import { IPUSH4Core } from "../src/interface/IPUSH4Core.sol";
import { IPUSH4Renderer } from "../src/interface/IPUSH4Renderer.sol";
import { PUSH4RendererMock } from "./mocks/PUSH4RendererMock.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";
import { PUSH4TestBase } from "./PUSH4TestBase.sol";

contract PUSH4RendererTest is PUSH4TestBase {
    address public owner = address(this);
    address public tokenOwner = makeAddr("tokenOwner");
    address public alice = makeAddr("alice");

    uint256 public constant WIDTH = 15;
    uint256 public constant HEIGHT = 25;
    uint256 public constant PIXEL_SIZE = 20;
    uint256 public constant TOTAL_PIXELS = WIDTH * HEIGHT; // 375

    string constant METADATA =
        unicode"\"name\": \"PUSH4\",\"description\": \"A heavily compressed and dithered down version of Barnett Newman's Onement I, encoded in 375 smart contract function selectors.\"";

    function setUp() public {
        _fullSetup(owner, WIDTH, HEIGHT, PIXEL_SIZE, METADATA);
    }

    /*//////////////////////////////////////////////////////////////
                              FFI HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Read selectors from JSON file using FFI
    function _getSelectorsFromJson() internal returns (bytes4[] memory) {
        string[] memory inputs = new string[](3);
        inputs[0] = "node";
        inputs[1] = "-e";
        inputs[2] =
            "const fs=require('fs');const d=JSON.parse(fs.readFileSync('ts-scripts/data/selector-contract-metadata.json','utf8'));process.stdout.write(d.selectors.map(s=>s.slice(2)).join(''));";

        bytes memory result = vm.ffi(inputs);

        // Result is raw bytes - Foundry converts hex output to bytes
        // Each selector is 4 bytes, total: 375 selectors * 4 bytes = 1500 bytes
        bytes4[] memory selectors = new bytes4[](TOTAL_PIXELS);

        for (uint256 i = 0; i < TOTAL_PIXELS; i++) {
            bytes4 selector;
            uint256 offset = i * 4;

            // Extract 4 bytes directly using assembly
            assembly {
                selector := mload(add(add(result, 0x20), offset))
            }
            selectors[i] = selector;
        }

        return selectors;
    }

    /// @notice Sort selectors by column index (last byte) - mirrors contract logic
    function _sortByIndex(bytes4[] memory data) internal pure returns (bytes4[] memory) {
        bytes4[] memory sorted = new bytes4[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            sorted[i] = data[i];
        }

        // Bubble sort by last byte
        for (uint256 i = 0; i < sorted.length; i++) {
            for (uint256 j = 0; j < sorted.length - i - 1; j++) {
                uint8 colIndex1 = uint8(sorted[j][3]);
                uint8 colIndex2 = uint8(sorted[j + 1][3]);

                if (colIndex1 > colIndex2) {
                    bytes4 temp = sorted[j];
                    sorted[j] = sorted[j + 1];
                    sorted[j + 1] = temp;
                }
            }
        }

        return sorted;
    }

    /*//////////////////////////////////////////////////////////////
                       SELECTOR EXTRACTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_extractSelectorsFromBytecode_returnsExactSelectorsFromJson() public {
        // Get selectors from JSON via FFI
        bytes4[] memory expectedSelectors = _getSelectorsFromJson();

        // Extract selectors from PUSH4 bytecode
        bytes4[] memory extractedSelectors =
            rendererMock.extractSelectorsFromBytecode(address(push4), TOTAL_PIXELS, false);

        // Verify count matches
        assertEq(extractedSelectors.length, TOTAL_PIXELS, "Should extract 375 selectors");

        // Verify each selector matches (extracted order may differ, so we check if all are present)
        // The JSON has selectors in sorted order, extraction order depends on bytecode layout
        for (uint256 i = 0; i < TOTAL_PIXELS; i++) {
            bool found = false;
            for (uint256 j = 0; j < TOTAL_PIXELS; j++) {
                if (extractedSelectors[j] == expectedSelectors[i]) {
                    found = true;
                    break;
                }
            }
            assertTrue(found, string(abi.encodePacked("Selector at index ", LibString.toString(i), " not found")));
        }
    }

    /*//////////////////////////////////////////////////////////////
                            SORTING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_sortBytecodesByIndex_sortsCorrectlyByLastByte() public view {
        // Get pixels from carved mode (which internally sorts)
        bytes4[] memory sortedPixels = renderer.getPixels(IPUSH4Core.Mode.Carved);

        // Verify pixels are sorted by column index (last byte)
        for (uint256 i = 1; i < sortedPixels.length; i++) {
            uint8 prevColumn = uint8(sortedPixels[i - 1][3]);
            uint8 currColumn = uint8(sortedPixels[i][3]);
            assertTrue(prevColumn <= currColumn, "Pixels should be sorted by column index");
        }

        // Verify column indices range from 0x00 to 0x0e (15 columns)
        uint8 minColumn = 255;
        uint8 maxColumn = 0;
        for (uint256 i = 0; i < sortedPixels.length; i++) {
            uint8 col = uint8(sortedPixels[i][3]);
            if (col < minColumn) minColumn = col;
            if (col > maxColumn) maxColumn = col;
        }
        assertEq(minColumn, 0, "Min column should be 0");
        assertEq(maxColumn, WIDTH - 1, "Max column should be WIDTH-1 (14)");
    }

    /*//////////////////////////////////////////////////////////////
                          CARVED MODE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getPixels_carvedMode_returnsExactPixelsFromJson() public {
        // Get expected pixels from JSON
        bytes4[] memory jsonSelectors = _getSelectorsFromJson();

        // Get pixels from renderer (sorted by column index)
        bytes4[] memory actualPixels = renderer.getPixels(IPUSH4Core.Mode.Carved);

        // Verify count
        assertEq(actualPixels.length, TOTAL_PIXELS, "Should return 375 pixels");

        // Verify all JSON selectors are present in actualPixels (unordered comparison)
        // This accounts for the fact that bytecode extraction order differs from JSON order
        for (uint256 i = 0; i < TOTAL_PIXELS; i++) {
            bool found = false;
            for (uint256 j = 0; j < TOTAL_PIXELS; j++) {
                if (actualPixels[j] == jsonSelectors[i]) {
                    found = true;
                    break;
                }
            }
            assertTrue(
                found,
                string(abi.encodePacked("JSON selector at index ", LibString.toString(i), " not found in getPixels"))
            );
        }

        // Verify all actualPixels are in JSON (reverse check)
        for (uint256 i = 0; i < TOTAL_PIXELS; i++) {
            bool found = false;
            for (uint256 j = 0; j < TOTAL_PIXELS; j++) {
                if (jsonSelectors[j] == actualPixels[i]) {
                    found = true;
                    break;
                }
            }
            assertTrue(
                found,
                string(abi.encodePacked("getPixels selector at index ", LibString.toString(i), " not found in JSON"))
            );
        }
    }

    function test_getPixels_carvedMode_returnsCorrectLength() public view {
        bytes4[] memory pixels = renderer.getPixels(IPUSH4Core.Mode.Carved);
        assertEq(pixels.length, TOTAL_PIXELS, "Should return 375 pixels");
    }

    /*//////////////////////////////////////////////////////////////
                          EXECUTED MODE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getPixels_executedMode_returnsTransformedPixels() public {
        // Mint token and set proxy
        push4Core.mint(tokenOwner);
        vm.startPrank(tokenOwner);
        push4Core.setProxy(address(proxyTemplate));
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        vm.stopPrank();

        // Get carved pixels for comparison
        bytes4[] memory carvedPixels = renderer.getPixels(IPUSH4Core.Mode.Carved);

        // Get executed pixels
        bytes4[] memory executedPixels = renderer.getPixels(IPUSH4Core.Mode.Executed);

        // Verify count
        assertEq(executedPixels.length, TOTAL_PIXELS, "Should return 375 pixels");

        // Verify each pixel is the result of proxyTemplate.execute(carvedPixel)
        for (uint256 i = 0; i < TOTAL_PIXELS; i++) {
            bytes4 expected = proxyTemplate.execute(carvedPixels[i]);
            assertEq(
                executedPixels[i],
                expected,
                string(abi.encodePacked("Executed pixel mismatch at index ", LibString.toString(i)))
            );
        }
    }

    function test_getPixels_executedMode_transformsDarkColors() public {
        // The PUSH4ProxyTemplate transforms dark colors (luminance < 100) to off-black
        // Mint and set proxy
        push4Core.mint(tokenOwner);
        vm.startPrank(tokenOwner);
        push4Core.setProxy(address(proxyTemplate));
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        vm.stopPrank();

        bytes4[] memory carvedPixels = renderer.getPixels(IPUSH4Core.Mode.Carved);
        bytes4[] memory executedPixels = renderer.getPixels(IPUSH4Core.Mode.Executed);

        // Count how many pixels were transformed (dark colors become off-black)
        uint256 transformedCount = 0;
        for (uint256 i = 0; i < TOTAL_PIXELS; i++) {
            if (carvedPixels[i] != executedPixels[i]) {
                transformedCount++;

                // Verify transformed pixels have low RGB values (off-black: 0-15 range)
                uint8 r = uint8(executedPixels[i][0]);
                uint8 g = uint8(executedPixels[i][1]);
                uint8 b = uint8(executedPixels[i][2]);
                assertTrue(r < 16 && g < 16 && b < 16, "Transformed pixel should be off-black");
            }
        }

        // Should have some transformed pixels (the dark brown background)
        assertGt(transformedCount, 0, "Should have transformed some dark pixels");
    }

    /*//////////////////////////////////////////////////////////////
                          SVG GENERATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getSvg_carvedMode_containsCorrectPixelColors() public view {
        string memory svg = renderer.getSvg();
        bytes4[] memory pixels = renderer.getPixels(IPUSH4Core.Mode.Carved);

        // Check first pixel color is in SVG
        bytes4 firstPixel = pixels[0];
        string memory firstColor = string(
            abi.encodePacked(
                "#", LibString.toHexStringNoPrefix(abi.encodePacked(firstPixel[0], firstPixel[1], firstPixel[2]))
            )
        );
        assertTrue(LibString.contains(svg, firstColor), "SVG should contain first pixel color");

        // Check SVG structure
        assertTrue(LibString.contains(svg, '<rect x="0" y="0"'), "SVG should contain first rect at (0,0)");
    }

    function test_getSvg_executedMode_containsCorrectTransformedColors() public {
        // Set up executed mode with proxy
        push4Core.mint(tokenOwner);
        vm.startPrank(tokenOwner);
        push4Core.setProxy(address(proxyTemplate));
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        vm.stopPrank();

        string memory svg = renderer.getSvg();
        bytes4[] memory pixels = renderer.getPixels(IPUSH4Core.Mode.Executed);

        // Check first pixel color is in SVG
        bytes4 firstPixel = pixels[0];
        string memory firstColor = string(
            abi.encodePacked(
                "#", LibString.toHexStringNoPrefix(abi.encodePacked(firstPixel[0], firstPixel[1], firstPixel[2]))
            )
        );
        assertTrue(LibString.contains(svg, firstColor), "SVG should contain first executed pixel color");
    }

    function test_getSvg_rectsInCorrectOrder() public view {
        string memory svg = renderer.getSvg();
        bytes4[] memory pixels = renderer.getPixels(IPUSH4Core.Mode.Carved);

        // Track current column and row within column (mirrors getSvg logic)
        uint256 currentCol = 0;
        uint256 rowInCol = 0;

        // Verify every single rect is in correct order with correct position and color
        for (uint256 i = 0; i < pixels.length; i++) {
            // Get column index from last byte
            uint256 x = uint256(uint8(pixels[i][3]));

            // Track which row we're at within the current column
            if (i > 0 && x != currentCol) {
                currentCol = x;
                rowInCol = 0;
            }

            uint256 y = rowInCol;
            rowInCol++;

            // Build the expected rect string
            bytes4 pixel = pixels[i];
            string memory color = string(
                abi.encodePacked("#", LibString.toHexStringNoPrefix(abi.encodePacked(pixel[0], pixel[1], pixel[2])))
            );

            string memory expectedRect = string(
                abi.encodePacked(
                    '<rect x="',
                    LibString.toString(x),
                    '" y="',
                    LibString.toString(y),
                    '" width="1" height="1" fill="',
                    color,
                    '"/>'
                )
            );

            assertTrue(
                LibString.contains(svg, expectedRect),
                string(
                    abi.encodePacked(
                        "Rect at index ",
                        LibString.toString(i),
                        " should be at (",
                        LibString.toString(x),
                        ",",
                        LibString.toString(y),
                        ") with color ",
                        color
                    )
                )
            );
        }

        // Verify we have exactly the right number of rects (375)
        // Count occurrences of '<rect' in svg
        uint256 rectCount = 0;
        bytes memory svgBytes = bytes(svg);
        bytes memory rectTag = bytes("<rect");
        for (uint256 i = 0; i <= svgBytes.length - rectTag.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < rectTag.length; j++) {
                if (svgBytes[i + j] != rectTag[j]) {
                    found = false;
                    break;
                }
            }
            if (found) rectCount++;
        }
        assertEq(rectCount, TOTAL_PIXELS, "SVG should contain exactly 375 rect elements");
    }

    function test_getSvg_containsCorrectDimensions() public view {
        string memory svg = renderer.getSvg();

        // Check dimensions: WIDTH * PIXEL_SIZE = 15 * 20 = 300
        string memory widthStr = LibString.toString(WIDTH * PIXEL_SIZE);
        string memory heightStr = LibString.toString(HEIGHT * PIXEL_SIZE);

        assertTrue(LibString.contains(svg, widthStr), "SVG should contain correct width");
        assertTrue(LibString.contains(svg, heightStr), "SVG should contain correct height");
    }

    function test_getSvg_containsViewBox() public view {
        string memory svg = renderer.getSvg();
        string memory viewBox =
            string(abi.encodePacked('viewBox="0 0 ', LibString.toString(WIDTH), " ", LibString.toString(HEIGHT), '"'));

        assertTrue(LibString.contains(svg, viewBox), "SVG should contain correct viewBox");
    }

    function test_getSvg_hasCorrectStructure() public view {
        string memory svg = renderer.getSvg();

        assertTrue(LibString.startsWith(svg, '<svg xmlns="http://www.w3.org/2000/svg"'), "Should start with svg tag");
        assertTrue(LibString.endsWith(svg, "</svg>"), "Should end with closing svg tag");
        assertTrue(LibString.contains(svg, 'shape-rendering="crispEdges"'), "Should have crisp edges");
    }

    /*//////////////////////////////////////////////////////////////
                          DATA URI TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getSvgDataUri_encodesBase64Correctly() public view {
        string memory svg = renderer.getSvg();
        string memory svgDataUri = renderer.getSvgDataUri();

        // Should have correct prefix
        assertTrue(LibString.startsWith(svgDataUri, "data:image/svg+xml;base64,"), "Should have correct prefix");

        // Base64 decode and compare
        string memory expectedDataUri =
            string(abi.encodePacked("data:image/svg+xml;base64,", Base64.encode(bytes(svg))));
        assertEq(svgDataUri, expectedDataUri, "Data URI should match base64 encoded SVG");
    }

    function test_getMetadataDataUri_encodesCorrectly() public view {
        string memory metadata = renderer.getMetadata();
        string memory metadataDataUri = renderer.getMetadataDataUri();

        // Should have correct prefix
        assertTrue(LibString.startsWith(metadataDataUri, "data:application/json;base64,"), "Should have JSON prefix");

        // Compare with expected
        string memory expectedDataUri =
            string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(metadata))));
        assertEq(metadataDataUri, expectedDataUri, "Metadata data URI should match");
    }

    /*//////////////////////////////////////////////////////////////
                          METADATA TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getMetadata_returnsValidJson() public view {
        string memory metadata = renderer.getMetadata();

        // Should be valid JSON structure
        assertTrue(LibString.startsWith(metadata, "{"), "Should start with opening brace");
        assertTrue(LibString.endsWith(metadata, "}"), "Should end with closing brace");

        // Should contain required fields
        assertTrue(LibString.contains(metadata, '"name"'), "Should contain name field");
        assertTrue(LibString.contains(metadata, '"description"'), "Should contain description field");
        assertTrue(LibString.contains(metadata, '"image"'), "Should contain image field");
        assertTrue(LibString.contains(metadata, "PUSH4"), "Should contain PUSH4 name");
    }

    function test_getMetadata_embedsSvgDataUri() public view {
        string memory metadata = renderer.getMetadata();
        string memory svgDataUri = renderer.getSvgDataUri();

        assertTrue(LibString.contains(metadata, svgDataUri), "Metadata should embed SVG data URI");
    }

    /*//////////////////////////////////////////////////////////////
                          KNOWN FALSE SELECTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isKnownFalseSelector_returnsTrueForAllKnownSelectors() public view {
        bytes4[11] memory falseSelectors = renderer.getKnownFalseSelectors();

        for (uint256 i = 0; i < falseSelectors.length; i++) {
            assertTrue(
                renderer.isKnownFalseSelector(falseSelectors[i]),
                string(abi.encodePacked("Selector at index ", LibString.toString(i), " should be known false"))
            );
        }
    }

    function test_isKnownFalseSelector_returnsFalseForValidSelectors() public {
        // Get valid selectors from JSON
        bytes4[] memory validSelectors = _getSelectorsFromJson();

        // Test all valid selectors
        for (uint256 i = 0; i < validSelectors.length; i++) {
            assertFalse(
                renderer.isKnownFalseSelector(validSelectors[i]),
                string(abi.encodePacked("Valid selector ", LibString.toString(i), " should not be known false"))
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                             ERROR CASES
    //////////////////////////////////////////////////////////////*/

    function test_getPixels_executedMode_revertsWithRandomProxy() public {
        // Mint token and set random address as proxy
        push4Core.mint(tokenOwner);
        address randomProxy = makeAddr("randomProxy");

        vm.startPrank(tokenOwner);
        push4Core.setProxy(randomProxy);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        vm.stopPrank();

        // Should revert when trying to get executed pixels
        vm.expectRevert(IPUSH4Renderer.FailedToCallFunction.selector);
        renderer.getPixels(IPUSH4Core.Mode.Executed);
    }

    function test_extractSelectorsFromBytecode_revertsForAddressWithNoCode() public {
        address eoa = makeAddr("eoa");

        vm.expectRevert(IPUSH4Renderer.NoCodeAtTarget.selector);
        rendererMock.extractSelectorsFromBytecode(eoa, TOTAL_PIXELS, false);
    }

    function test_extractSelectorsFromBytecode_revertsForZeroAddress() public {
        vm.expectRevert(IPUSH4Renderer.NoCodeAtTarget.selector);
        rendererMock.extractSelectorsFromBytecode(address(0), TOTAL_PIXELS, false);
    }

    /*//////////////////////////////////////////////////////////////
                          OWNER-ONLY SETTER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setWidth_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        renderer.setWidth(20);
    }

    function test_setHeight_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        renderer.setHeight(30);
    }

    function test_setPixelSize_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        renderer.setPixelSize(10);
    }

    function test_setPush4Core_revertsWhenNotOwner() public {
        PUSH4Core newCore = new PUSH4Core(address(push4), owner);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        renderer.setPush4Core(newCore);
    }

    function test_setMetadata_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        renderer.setMetadata("new metadata");
    }

    /*//////////////////////////////////////////////////////////////
                          GRACE PERIOD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setWidth_revertsAfterGracePeriod() public {
        // Warp past grace period (60 days + 1 second)
        vm.warp(block.timestamp + 60 days + 1);

        vm.expectRevert(IPUSH4Renderer.NotInGracePeriod.selector);
        renderer.setWidth(20);
    }

    function test_setHeight_revertsAfterGracePeriod() public {
        vm.warp(block.timestamp + 60 days + 1);

        vm.expectRevert(IPUSH4Renderer.NotInGracePeriod.selector);
        renderer.setHeight(30);
    }

    function test_setPixelSize_revertsAfterGracePeriod() public {
        vm.warp(block.timestamp + 60 days + 1);

        vm.expectRevert(IPUSH4Renderer.NotInGracePeriod.selector);
        renderer.setPixelSize(10);
    }

    function test_setPush4Core_revertsAfterGracePeriod() public {
        vm.warp(block.timestamp + 60 days + 1);

        PUSH4Core newCore = new PUSH4Core(address(push4), owner);
        vm.expectRevert(IPUSH4Renderer.NotInGracePeriod.selector);
        renderer.setPush4Core(newCore);
    }

    function test_setMetadata_revertsAfterGracePeriod() public {
        vm.warp(block.timestamp + 60 days + 1);

        vm.expectRevert(IPUSH4Renderer.NotInGracePeriod.selector);
        renderer.setMetadata("new metadata");
    }

    function test_setters_workWithinGracePeriod() public {
        // Within grace period, setters should work
        renderer.setWidth(20);
        assertEq(renderer.width(), 20);

        renderer.setHeight(30);
        assertEq(renderer.height(), 30);

        renderer.setPixelSize(10);
        assertEq(renderer.pixelSize(), 10);

        renderer.setMetadata("new metadata");
    }
}
