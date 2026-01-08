// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { IPUSH4Proxy } from "../../src/interface/IPUSH4Proxy.sol";

/**
 * @title MockPUSH4Proxy
 * @notice Mock implementation of IPUSH4Proxy for testing
 */
contract MockPUSH4Proxy is IPUSH4Proxy {
    string private _title;
    string private _description;
    Creator private _creator;

    // Transformation mode: 0 = passthrough, 1 = invert, 2 = grayscale
    uint8 public transformMode;

    constructor(
        string memory proxyTitle,
        string memory proxyDescription,
        string memory creatorName,
        address creatorWallet
    ) {
        _title = proxyTitle;
        _description = proxyDescription;
        _creator = Creator({ name: creatorName, wallet: creatorWallet });
    }

    /// @notice Execute pixel transformation
    function execute(bytes4 selector) external view returns (bytes4) {
        if (transformMode == 0) {
            // Passthrough - return as-is
            return selector;
        } else if (transformMode == 1) {
            // Invert colors
            uint8 r = 255 - uint8(selector[0]);
            uint8 g = 255 - uint8(selector[1]);
            uint8 b = 255 - uint8(selector[2]);
            uint8 index = uint8(selector[3]);
            return bytes4(bytes.concat(bytes1(r), bytes1(g), bytes1(b), bytes1(index)));
        } else {
            // Grayscale
            uint8 r = uint8(selector[0]);
            uint8 g = uint8(selector[1]);
            uint8 b = uint8(selector[2]);
            uint8 index = uint8(selector[3]);
            uint8 gray = uint8((uint16(r) + uint16(g) + uint16(b)) / 3);
            return bytes4(bytes.concat(bytes1(gray), bytes1(gray), bytes1(gray), bytes1(index)));
        }
    }

    /// @notice Get the proxy title
    function title() external view returns (string memory) {
        return _title;
    }

    /// @notice Get the proxy description
    function description() external view returns (string memory) {
        return _description;
    }

    /// @notice Get the creator information
    function creator() external view returns (Creator memory) {
        return _creator;
    }

    /// @notice Set the transformation mode
    function setTransformMode(uint8 mode) external {
        transformMode = mode;
    }
}

