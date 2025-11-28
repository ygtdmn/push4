// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { IPUSH4Renderer } from "./interface/IPUSH4Renderer.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";
import { IPUSH4Core } from "./interface/IPUSH4Core.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PUSH4Renderer
 * @author Yigit Duman
 */
contract PUSH4Renderer is IPUSH4Renderer, Ownable {
    IPUSH4Core public push4Core;

    string internal _metadata;

    uint256 public width;
    uint256 public height;
    uint256 public pixelSize;

    /// @notice Constructor
    /// @param _width The width of the image
    /// @param _height The height of the image
    /// @param _pixelSize The size of each pixel
    /// @param _push4Core The PUSH4Core contract
    /// @param __metadata The base metadata to be included in the tokenURI
    /// @param _owner The owner of the contract
    constructor(
        uint256 _width,
        uint256 _height,
        uint256 _pixelSize,
        IPUSH4Core _push4Core,
        string memory __metadata,
        address _owner
    )
        Ownable(_owner)
    {
        width = _width;
        height = _height;
        pixelSize = _pixelSize;
        push4Core = _push4Core;
        _metadata = __metadata;
    }

    /// @notice Gets the pixels for the given mode
    /// @param mode The mode to get the pixels for
    /// @return pixels The pixels for the given mode
    /// @dev This function extracts the selectors from the push4 contract and sorts them by column index
    function getPixels(IPUSH4Core.Mode mode) public view returns (bytes4[] memory) {
        bytes4[] memory selectors = _extractSelectorsFromBytecode(push4Core.push4(), width * height, false);
        bytes4[] memory sorted = _sortBytecodesByIndex(selectors);

        if (mode == IPUSH4Core.Mode.Carved) {
            return sorted;
        }

        bytes4[] memory outputs = new bytes4[](selectors.length);

        for (uint256 i = 0; i < sorted.length; i++) {
            (bool success, bytes memory result) = push4Core.push4().staticcall(abi.encodePacked(sorted[i]));

            require(success && result.length >= 32, FailedToCallFunction());
            outputs[i] = abi.decode(result, (bytes4));
        }

        return outputs;
    }

    /// @notice Builds the SVG for the current mode
    /// @return svg The SVG for the current mode
    function getSvg() public view returns (string memory) {
        // Get pixel data based on mode
        bytes4[] memory pixels = getPixels(push4Core.mode());

        // Build SVG
        string memory svg = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="',
                LibString.toString(width * pixelSize),
                '" height="',
                LibString.toString(height * pixelSize),
                '" viewBox="0 0 ',
                LibString.toString(width),
                " ",
                LibString.toString(height),
                '" shape-rendering="crispEdges">'
            )
        );

        uint256 currentCol = 0;
        uint256 rowInCol = 0;

        for (uint256 i = 0; i < pixels.length && i < width * height; i++) {
            // Get column index from last byte
            uint256 x = uint256(uint8(pixels[i][3]));

            // Track which row we're at within the current column
            if (i > 0 && x != currentCol) {
                // Moved to next column, reset row counter
                currentCol = x;
                rowInCol = 0;
            }

            uint256 y = rowInCol;
            rowInCol++;

            // Extract RGB from the 4-byte pixel (ignore 4th byte which is index)
            bytes4 pixel = pixels[i];
            string memory color = string(
                abi.encodePacked("#", LibString.toHexStringNoPrefix(abi.encodePacked(pixel[0], pixel[1], pixel[2])))
            );

            // Add rect element
            svg = string(
                abi.encodePacked(
                    svg,
                    '<rect x="',
                    LibString.toString(x),
                    '" y="',
                    LibString.toString(y),
                    '" width="1" height="1" fill="',
                    color,
                    '"/>'
                )
            );
        }

        svg = string(abi.encodePacked(svg, "</svg>"));
        return svg;
    }

    /// @notice Generates the SVG data URI for the current mode
    /// @return svgDataUri The SVG data URI for the current mode
    function getSvgDataUri() public view returns (string memory) {
        // Generate SVG from pixel data
        string memory svg = getSvg();

        // Base64 encode the SVG
        string memory base64Svg = Base64.encode(bytes(svg));

        return string(abi.encodePacked("data:image/svg+xml;base64,", base64Svg));
    }

    /// @notice Generates the metadata for the current mode
    /// @return metadata The metadata for the current mode
    function getMetadata() public view returns (string memory) {
        return string(abi.encodePacked("{", _metadata, ', "image": "', getSvgDataUri(), '"}'));
    }

    /// @notice Generates the metadata data URI for the current mode
    /// @return metadataDataUri The metadata data URI for the current mode
    function getMetadataDataUri() public view returns (string memory) {
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(getMetadata()))));
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyInGracePeriod() {
        _inGracePeriod();
        _;
    }

    function _inGracePeriod() internal view {
        require(push4Core.inGracePeriod(), NotInGracePeriod());
    }

    /// @notice Sets the width of the image
    /// @param _width The new width
    function setWidth(uint256 _width) external onlyOwner onlyInGracePeriod {
        width = _width;
    }

    /// @notice Sets the height of the image
    /// @param _height The new height
    function setHeight(uint256 _height) external onlyOwner onlyInGracePeriod {
        height = _height;
    }

    /// @notice Sets the pixel size
    /// @param _pixelSize The new pixel size
    function setPixelSize(uint256 _pixelSize) external onlyOwner onlyInGracePeriod {
        pixelSize = _pixelSize;
    }

    /// @notice Sets the PUSH4Core contract
    /// @param _push4Core The new PUSH4Core contract
    function setPush4Core(IPUSH4Core _push4Core) external onlyOwner onlyInGracePeriod {
        push4Core = _push4Core;
    }

    /// @notice Sets the metadata
    /// @param __metadata The new metadata
    function setMetadata(string memory __metadata) external onlyOwner onlyInGracePeriod {
        _metadata = __metadata;
    }

    /*//////////////////////////////////////////////////////////////
                                 UTILITY
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Convert bytes4 array to bytes
     * @param data Array of bytes4 values
     * @return result Concatenated bytes
     */
    function _bytes4ArrayToBytes(bytes4[] memory data) internal pure returns (bytes memory result) {
        result = new bytes(data.length * 4);
        for (uint256 i = 0; i < data.length; i++) {
            bytes4 val = data[i];
            uint256 offset = i * 4;
            result[offset] = val[0];
            result[offset + 1] = val[1];
            result[offset + 2] = val[2];
            result[offset + 3] = val[3];
        }
        return result;
    }

    /**
     * @notice Read bytes from address using extcodecopy
     * @param target Address to read from
     * @param offset Offset in bytecode
     * @param length Number of bytes to read
     * @return data The read bytes
     */
    function _readBytecode(address target, uint256 offset, uint256 length) internal view returns (bytes memory data) {
        data = new bytes(length);
        assembly {
            extcodecopy(target, add(data, 0x20), offset, length)
        }
        return data;
    }

    /**
     * @notice Get deployed bytecode size of a contract
     * @param target Address to check
     * @return size The size in bytes
     */
    function _getCodeSize(address target) internal view returns (uint256 size) {
        assembly {
            size := extcodesize(target)
        }
        return size;
    }

    /**
     * @notice Extract function selectors from deployed bytecode by parsing function dispatch
     * @dev Searches for PUSH4 opcodes (0x63) followed by 4-byte selectors in the bytecode
     * @param target Address of the contract
     * @param expectedCount Expected number of selectors
     * @param shouldFilterKnownFalseSelectors Whether to filter out known false selectors
     * @return selectors Array of found selectors in order
     */
    function _extractSelectorsFromBytecode(
        address target,
        uint256 expectedCount,
        bool shouldFilterKnownFalseSelectors
    )
        internal
        view
        returns (bytes4[] memory)
    {
        uint256 codeSize = _getCodeSize(target);
        require(codeSize > 0, NoCodeAtTarget());

        // Read the entire bytecode
        bytes memory code = _readBytecode(target, 0, codeSize);

        // Find all PUSH4 opcodes (0x63) which are used for function selectors
        bytes4[] memory foundSelectors = new bytes4[](expectedCount);
        uint256 count = 0;

        for (uint256 i = 0; i < code.length && count < expectedCount; i++) {
            // Look for PUSH4 opcode (0x63)
            if (uint8(code[i]) == 0x63 && i + 4 < code.length) {
                bytes4 selector;
                assembly {
                    // Load 32 bytes starting at position i+1 (after the PUSH4 opcode)
                    // code is a bytes array, so data starts at code + 0x20 (32 bytes for length prefix)
                    selector := mload(add(add(code, 0x20), add(i, 1)))
                }

                if (!shouldFilterKnownFalseSelectors || !isKnownFalseSelector(selector)) {
                    foundSelectors[count] = selector;
                    count++;
                }
            }
        }

        return foundSelectors;
    }

    /**
     * @notice Sort bytes4 array by column index (last byte)
     * @dev The last byte of each selector contains the column index
     *      After Solidity sorts selectors alphabetically during compilation,
     *      this function reconstructs the original column order, preserving vertical structures
     * @param data Array of bytes4 values to sort
     * @return sorted Sorted array ordered by column index (ascending)
     */
    function _sortBytecodesByIndex(bytes4[] memory data) internal pure returns (bytes4[] memory) {
        bytes4[] memory sorted = new bytes4[](data.length);

        // Copy array
        for (uint256 i = 0; i < data.length; i++) {
            sorted[i] = data[i];
        }

        // Bubble sort by last byte (column index)
        for (uint256 i = 0; i < sorted.length; i++) {
            for (uint256 j = 0; j < sorted.length - i - 1; j++) {
                uint8 colIndex1 = uint8(sorted[j][3]);
                uint8 colIndex2 = uint8(sorted[j + 1][3]);

                if (colIndex1 > colIndex2) {
                    // Swap
                    bytes4 temp = sorted[j];
                    sorted[j] = sorted[j + 1];
                    sorted[j + 1] = temp;
                }
            }
        }

        return sorted;
    }

    /// @notice Returns a list of known false-positive function selectors
    /// @dev These bytes don't represent pixels in the image; some are misinterpreted as selectors
    ///      and others are from external calls
    /// @return An array of 11 bytes4 values representing known false-positive selectors
    function getKnownFalseSelectors() public pure returns (bytes4[11] memory) {
        return [
            bytes4(0xec556889),
            bytes4(0x6f2885b9),
            bytes4(0x57509495),
            bytes4(0x4e487b71),
            bytes4(0x4e487b71),
            bytes4(0x616c6c20),
            bytes4(0x75746520),
            bytes4(0x81526403),
            bytes4(0x4300081e),
            bytes4(0x00000000),
            bytes4(0xde510b72)
        ];
    }

    /// @notice Checks if a given selector is a known false-positive selector
    /// @param selector The selector to check
    /// @return True if the selector is a known false-positive selector, false otherwise
    function isKnownFalseSelector(bytes4 selector) public pure returns (bool) {
        bytes4[11] memory knownFalseSelectors = getKnownFalseSelectors();
        return selector == knownFalseSelectors[0] || selector == knownFalseSelectors[1]
            || selector == knownFalseSelectors[2] || selector == knownFalseSelectors[3]
            || selector == knownFalseSelectors[4] || selector == knownFalseSelectors[5]
            || selector == knownFalseSelectors[6] || selector == knownFalseSelectors[7]
            || selector == knownFalseSelectors[8] || selector == knownFalseSelectors[9]
            || selector == knownFalseSelectors[10];
    }
}
