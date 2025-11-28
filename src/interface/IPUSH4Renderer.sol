// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { IPUSH4Core } from "./IPUSH4Core.sol";

interface IPUSH4Renderer {
    // Errors
    error FailedToCallFunction();
    error NoCodeAtTarget();
    error NotInGracePeriod();

    // State variable getters
    function width() external view returns (uint256);
    function height() external view returns (uint256);
    function pixelSize() external view returns (uint256);
    function push4Core() external view returns (IPUSH4Core);

    // View functions
    function getPixels(IPUSH4Core.Mode mode) external view returns (bytes4[] memory);
    function getSvg() external view returns (string memory);
    function getSvgDataUri() external view returns (string memory);
    function getMetadata() external view returns (string memory);
    function getMetadataDataUri() external view returns (string memory);
    function getKnownFalseSelectors() external pure returns (bytes4[11] memory);
    function isKnownFalseSelector(bytes4 selector) external pure returns (bool);
}
