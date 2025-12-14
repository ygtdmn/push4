// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { IPUSH4RendererRouter } from "./interface/IPUSH4RendererRouter.sol";
import { IPUSH4Renderer } from "./interface/IPUSH4Renderer.sol";
import { IPUSH4Core } from "./interface/IPUSH4Core.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PUSH4RendererRouter
 * @author Yigit Duman
 * @notice A router contract that delegates rendering to another renderer contract.
 *         This allows changing the underlying renderer without the grace period limit
 *         imposed by PUSH4Core. Once satisfied, the renderer can be locked permanently.
 */
contract PUSH4RendererRouter is IPUSH4RendererRouter, Ownable {
    IPUSH4Renderer public renderer;
    bool public isLocked;

    constructor(IPUSH4Renderer _renderer, address _owner) Ownable(_owner) {
        require(address(_renderer) != address(0), InvalidRenderer());
        renderer = _renderer;
        emit RendererSet(_renderer);
    }

    modifier notLocked() {
        require(!isLocked, RendererIsLocked());
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setRenderer(IPUSH4Renderer _renderer) external onlyOwner notLocked {
        require(address(_renderer) != address(0), InvalidRenderer());
        renderer = _renderer;
        emit RendererSet(_renderer);
    }

    function lockRenderer() external onlyOwner notLocked {
        isLocked = true;
        emit RendererLocked(renderer);
    }

    /*//////////////////////////////////////////////////////////////
                         IPUSH4RENDERER PASSTHROUGH
    //////////////////////////////////////////////////////////////*/

    function width() external view returns (uint256) {
        return renderer.width();
    }

    function height() external view returns (uint256) {
        return renderer.height();
    }

    function pixelSize() external view returns (uint256) {
        return renderer.pixelSize();
    }

    function push4Core() external view returns (IPUSH4Core) {
        return renderer.push4Core();
    }

    function getPixels(IPUSH4Core.Mode mode) external view returns (bytes4[] memory) {
        return renderer.getPixels(mode);
    }

    function getSvg() external view returns (string memory) {
        return renderer.getSvg();
    }

    function getSvgDataUri() external view returns (string memory) {
        return renderer.getSvgDataUri();
    }

    function getMetadata() external view returns (string memory) {
        return renderer.getMetadata();
    }

    function getMetadataDataUri() external view returns (string memory) {
        return renderer.getMetadataDataUri();
    }

    // The following functions are implemented locally as pure functions and do not require routing or updates.
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
