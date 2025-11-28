// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";
import { PUSH4Renderer } from "../../src/PUSH4Renderer.sol";
import { IPUSH4Renderer } from "../../src/interface/IPUSH4Renderer.sol";
import { IPUSH4Core } from "../../src/interface/IPUSH4Core.sol";
import { PUSH4 } from "../../src/PUSH4.sol";
import { PUSH4Core } from "../../src/PUSH4Core.sol";
import { LibString } from "solady/utils/LibString.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { PUSH4TestBase } from "../PUSH4TestBase.sol";

contract PUSH4RendererGemini3ProTest is PUSH4TestBase {
    address public owner = address(this);

    string constant METADATA = unicode"\"name\": \"PUSH4 Test\"";
    uint256 constant WIDTH = 10;
    uint256 constant HEIGHT = 10;
    uint256 constant PIXEL_SIZE = 10;

    function setUp() public {
        _deployPush4();
        _deployPush4Core(owner);
        renderer = new PUSH4Renderer(
            WIDTH,
            HEIGHT,
            PIXEL_SIZE,
            push4Core,
            METADATA,
            owner
        );
        push4Core.setRenderer(renderer);
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsStateVariables() public view {
        assertEq(renderer.width(), WIDTH);
        assertEq(renderer.height(), HEIGHT);
        assertEq(renderer.pixelSize(), PIXEL_SIZE);
        assertEq(address(renderer.push4Core()), address(push4Core));
        assertEq(renderer.owner(), owner);
    }

    /*//////////////////////////////////////////////////////////////
                               GET PIXELS
    //////////////////////////////////////////////////////////////*/

    function test_getPixels_Carved_returnsSortedSelectors() public view {
        // Mode is already Carved in setup
        bytes4[] memory pixels = renderer.getPixels(IPUSH4Core.Mode.Carved);
        
        assertGt(pixels.length, 0);
        
        // Verify sorting by last byte (column index)
        for (uint256 i = 0; i < pixels.length - 1; i++) {
            uint8 col1 = uint8(pixels[i][3]);
            uint8 col2 = uint8(pixels[i+1][3]);
            assertLe(col1, col2);
        }
    }

    function test_getPixels_Executed_callsContract() public view {
        bytes4[] memory pixels = renderer.getPixels(IPUSH4Core.Mode.Executed);
        
        // In PUSH4 contract, functions return their own selector (msg.sig)
        // So executed pixels should match the carved pixels (which are the selectors)
        // unless PUSH4 logic changes. PUSH4._e returns msg.sig by default.
        
        bytes4[] memory carvedPixels = renderer.getPixels(IPUSH4Core.Mode.Carved);
        assertEq(pixels.length, carvedPixels.length);
        
        for(uint256 i = 0; i < pixels.length; i++) {
            assertEq(pixels[i], carvedPixels[i]);
        }
    }

    function test_getPixels_Executed_RevertsIfCallFails() public {
        
        // We need code at the target for _getCodeSize check in extractSelectors
        // But wait, extractSelectors is called first on push4().
        // getPixels calls:
        // 1. _extractSelectorsFromBytecode(push4Core.push4(), ...)
        // 2. loops and calls push4Core.push4().staticcall(...)
        
        // So push4Core.push4() must have bytecode AND must revert on calls.
        // But Reverter has bytecode.
        // However, extractSelectors looks for PUSH4 opcodes. Reverter might not have enough PUSH4 opcodes to satisfy "width * height".
        // The renderer needs to find "width * height" selectors.
        
        // So I need a contract that has bytecode with PUSH4 opcodes (like PUSH4) BUT reverts when called.
        // I can etch PUSH4 code to the address, but then mockCallRevert specific calls.
        
        address target = makeAddr("revertingTarget");
        vm.etch(target, address(push4).code);
        
        // Update push4Core to point to the reverting target
        push4Core.setPush4(target);
        
        // Now I need to make sure the calls revert.
        // I'll use mockCallRevert with the specific selector I expect.
        // Or I can use the 3-argument mockCallRevert with empty data? No, that matches empty data.
        
        // Let's just mock ONE selector that we know will be called.
        // We can get the first pixel from the carved mode using the REAL push4, then mock that one.
        
        // 1. Get pixels from real PUSH4 to know what selector will be called
        // Note: We need to temporarily use the original push4 for this
        push4Core.setPush4(address(push4));
        bytes4[] memory selectors = renderer.getPixels(IPUSH4Core.Mode.Carved);
        bytes4 selectorToRevert = selectors[0];
        
        // 2. Set back to the reverting target
        push4Core.setPush4(target);
        
        // 3. Mock revert for that selector on target
        vm.mockCallRevert(
            target,
            abi.encodePacked(selectorToRevert),
            abi.encodePacked("Call failed")
        );
        
        vm.expectRevert(IPUSH4Renderer.FailedToCallFunction.selector);
        renderer.getPixels(IPUSH4Core.Mode.Executed);
    }

    /*//////////////////////////////////////////////////////////////
                                GET SVG
    //////////////////////////////////////////////////////////////*/

    function test_getSvg_returnsValidSvgStructure() public view {
        string memory svg = renderer.getSvg();
        
        assertTrue(LibString.startsWith(svg, '<svg xmlns="http://www.w3.org/2000/svg"'));
        assertTrue(LibString.endsWith(svg, "</svg>"));
        
        // Check dimensions in SVG
        // string memory widthStr = LibString.toString(WIDTH * PIXEL_SIZE);
        // string memory heightStr = LibString.toString(HEIGHT * PIXEL_SIZE);
        
        // Simple contains check (approximate)
        // Note: LibString doesn't have contains, but we can check expected parts
        // We can't easily check "contains" without a helper, but we can check if it parses or looks right manually if we really wanted to.
        // For now, checking start/end is a good sanity check.
    }

    function test_getSvgDataUri_returnsBase64EncodedSvg() public view {
        string memory dataUri = renderer.getSvgDataUri();
        assertTrue(LibString.startsWith(dataUri, "data:image/svg+xml;base64,"));
        
        // Decode and check if it contains expected SVG tag
        string memory base64Part = LibString.slice(dataUri, 26); // remove prefix
        bytes memory decoded = Base64.decode(base64Part);
        string memory decodedStr = string(decoded);
        
        assertTrue(LibString.startsWith(decodedStr, '<svg xmlns="http://www.w3.org/2000/svg"'));
    }

    /*//////////////////////////////////////////////////////////////
                                METADATA
    //////////////////////////////////////////////////////////////*/

    function test_getMetadata_returnsCorrectJson() public view {
        string memory metadata = renderer.getMetadata();
        
        // Expected format: {METADATA, "image": "DATA_URI"}
        string memory expectedStart = string(abi.encodePacked("{", METADATA, ', "image": "'));
        assertTrue(LibString.startsWith(metadata, expectedStart));
        assertTrue(LibString.endsWith(metadata, '"}'));
    }

    function test_getMetadataDataUri_returnsBase64EncodedJson() public view {
        string memory dataUri = renderer.getMetadataDataUri();
        assertTrue(LibString.startsWith(dataUri, "data:application/json;base64,"));
        
        string memory base64Part = LibString.slice(dataUri, 29); // remove prefix
        bytes memory decoded = Base64.decode(base64Part);
        string memory decodedStr = string(decoded);
        
        string memory expectedStart = string(abi.encodePacked("{", METADATA, ', "image": "'));
        assertTrue(LibString.startsWith(decodedStr, expectedStart));
    }

    /*//////////////////////////////////////////////////////////////
                                UTILS
    //////////////////////////////////////////////////////////////*/

    function test_getKnownFalseSelectors_returnsCorrectArray() public view {
        bytes4[11] memory known = renderer.getKnownFalseSelectors();
        assertEq(known.length, 11);
        assertEq(known[0], bytes4(0xec556889));
        // ... check last one
        assertEq(known[10], bytes4(0xde510b72));
    }

    function test_isKnownFalseSelector_returnsTrueForKnown() public view {
        assertTrue(renderer.isKnownFalseSelector(bytes4(0xec556889)));
        assertTrue(renderer.isKnownFalseSelector(bytes4(0xde510b72)));
    }

    function test_isKnownFalseSelector_returnsFalseForUnknown() public view {
        assertFalse(renderer.isKnownFalseSelector(bytes4(0x12345678)));
        assertFalse(renderer.isKnownFalseSelector(bytes4(0xdeadbeef)));
    }

    function test_extractSelectors_revertsIfNoCode() public {
        address emptyAccount = makeAddr("empty");
        
        // Update push4Core to point to an empty account
        push4Core.setPush4(emptyAccount);
        
        vm.expectRevert(IPUSH4Renderer.NoCodeAtTarget.selector);
        renderer.getPixels(IPUSH4Core.Mode.Carved);
    }
}
