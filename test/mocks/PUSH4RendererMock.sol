// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { PUSH4Renderer } from "../../src/PUSH4Renderer.sol";
import { IPUSH4Core } from "../../src/interface/IPUSH4Core.sol";

contract PUSH4RendererMock is PUSH4Renderer {
    constructor(
        uint256 _width,
        uint256 _height,
        uint256 _pixelSize,
        IPUSH4Core _push4Core,
        string memory __metadata,
        address _owner
    )
        PUSH4Renderer(_width, _height, _pixelSize, _push4Core, __metadata, _owner)
    { }

    function extractSelectorsFromBytecode(
        address target,
        uint256 expectedCount,
        bool shouldFilterKnownFalseSelectors
    )
        public
        view
        returns (bytes4[] memory)
    {
        return _extractSelectorsFromBytecode(target, expectedCount, shouldFilterKnownFalseSelectors);
    }
}
