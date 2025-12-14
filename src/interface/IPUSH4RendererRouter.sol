// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { IPUSH4Renderer } from "./IPUSH4Renderer.sol";

interface IPUSH4RendererRouter is IPUSH4Renderer {
    // Events
    event RendererSet(IPUSH4Renderer indexed newRenderer);
    event RendererLocked(IPUSH4Renderer indexed lockedRenderer);

    // Errors
    error RendererIsLocked();
    error InvalidRenderer();

    // State variable getters
    function renderer() external view returns (IPUSH4Renderer);
    function isLocked() external view returns (bool);

    // Admin functions
    function setRenderer(IPUSH4Renderer _renderer) external;
    function lockRenderer() external;
}

