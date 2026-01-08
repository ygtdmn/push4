// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { IPUSH4Renderer } from "./IPUSH4Renderer.sol";
import { IPUSH4Core } from "./IPUSH4Core.sol";
import { IMURIProtocol } from "./IMURIProtocol.sol";

interface IPUSH4RendererV2 is IPUSH4Renderer {
    error InvalidBlockInterval();
    event BlockIntervalUpdated(uint256 oldValue, uint256 newValue);
    event MURIProtocolUpdated(address indexed muriProtocol);

    function blockInterval() external view returns (uint256);
    function getAnimationUrl() external view returns (string memory);
}

