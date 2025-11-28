// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";
import { PUSH4 } from "../../src/PUSH4.sol";
import { PUSH4Core } from "../../src/PUSH4Core.sol";
import { IPUSH4Core } from "../../src/interface/IPUSH4Core.sol";
import { IPUSH4Renderer } from "../../src/interface/IPUSH4Renderer.sol";
import { PUSH4RendererMock } from "../../test/mocks/PUSH4RendererMock.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";
import { PUSH4TestBase } from "../PUSH4TestBase.sol";

contract PUSH4RendererGPT51CodexTest is PUSH4TestBase {
    uint256 public constant WIDTH = 15;
    uint256 public constant HEIGHT = 25;
    uint256 public constant PIXEL_SIZE = 20;
    uint256 public constant TOTAL_PIXELS = WIDTH * HEIGHT;

    string internal constant METADATA =
        unicode"\"name\": \"PUSH4\",\"description\": \"A heavily compressed and dithered down version of Barnett Newman's Onement I, encoded in 375 smart contract function selectors.\"";

    function setUp() public {
        _fullSetup(address(this), WIDTH, HEIGHT, PIXEL_SIZE, METADATA);
    }

    function test_getPixels_carvedReturnsSortedByColumnIndex() public view {
        bytes4[] memory carved = rendererMock.getPixels(IPUSH4Core.Mode.Carved);
        assertEq(carved.length, TOTAL_PIXELS);

        for (uint256 i = 1; i < carved.length; i++) {
            uint8 previousColumn = uint8(carved[i - 1][3]);
            uint8 currentColumn = uint8(carved[i][3]);
            assertTrue(previousColumn <= currentColumn, "columns out of order");
        }
    }

    function test_getPixels_executedStaticCallsPush4Selectors() public view {
        bytes4[] memory carved = rendererMock.getPixels(IPUSH4Core.Mode.Carved);
        bytes4[] memory executed = rendererMock.getPixels(IPUSH4Core.Mode.Executed);

        assertEq(executed.length, carved.length);

        address push4Address = push4Core.push4();
        bytes4 selector = carved[0];
        (bool ok, bytes memory result) = push4Address.staticcall(abi.encodePacked(selector));
        assertTrue(ok, "first selector call failed");
        bytes4 expected = abi.decode(result, (bytes4));
        assertEq(executed[0], expected);

        uint256 mid = carved.length / 2;
        selector = carved[mid];
        (ok, result) = push4Address.staticcall(abi.encodePacked(selector));
        assertTrue(ok, "mid selector call failed");
        expected = abi.decode(result, (bytes4));
        assertEq(executed[mid], expected);
    }

    function test_getSvg_containsDimensionsAndFirstPixelRect() public view {
        string memory svg = rendererMock.getSvg();

        string memory openingTag = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="',
                LibString.toString(WIDTH * PIXEL_SIZE),
                '" height="',
                LibString.toString(HEIGHT * PIXEL_SIZE),
                '" viewBox="0 0 ',
                LibString.toString(WIDTH),
                " ",
                LibString.toString(HEIGHT),
                '" shape-rendering="crispEdges">'
            )
        );

        assertTrue(_contains(svg, openingTag), "svg opening tag mismatch");
        assertTrue(_contains(svg, '<rect x="0" y="0" width="1" height="1"'), "missing first pixel rect");
    }

    function test_getSvgDataUri_matchesBase64Encoding() public view {
        string memory svg = rendererMock.getSvg();
        string memory expected = string(abi.encodePacked("data:image/svg+xml;base64,", Base64.encode(bytes(svg))));
        assertEq(rendererMock.getSvgDataUri(), expected);
    }

    function test_getMetadata_embedsSvgDataUri() public view {
        string memory expected = string(abi.encodePacked("{", METADATA, ', "image": "', rendererMock.getSvgDataUri(), '"}'));
        assertEq(rendererMock.getMetadata(), expected);
    }

    function test_getMetadataDataUri_matchesBase64Encoding() public view {
        string memory metadata = rendererMock.getMetadata();
        string memory expected =
            string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(metadata))));
        assertEq(rendererMock.getMetadataDataUri(), expected);
    }

    function test_extractSelectors_revertsWhenTargetHasNoCode() public {
        vm.expectRevert(IPUSH4Renderer.NoCodeAtTarget.selector);
        rendererMock.extractSelectorsFromBytecode(address(0), TOTAL_PIXELS, false);
    }

    function test_isKnownFalseSelector_matchesLookupTable() public view {
        bytes4[11] memory selectors = rendererMock.getKnownFalseSelectors();
        assertTrue(rendererMock.isKnownFalseSelector(selectors[0]));
        assertFalse(rendererMock.isKnownFalseSelector(bytes4(0x12345678)));
    }

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
}
