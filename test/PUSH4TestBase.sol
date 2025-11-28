// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";
import { PUSH4 } from "../src/PUSH4.sol";
import { PUSH4Core } from "../src/PUSH4Core.sol";
import { PUSH4Renderer } from "../src/PUSH4Renderer.sol";
import { PUSH4ProxyTemplate } from "../src/PUSH4ProxyTemplate.sol";
import { PUSH4RendererMock } from "./mocks/PUSH4RendererMock.sol";
import { IPUSH4Core } from "../src/interface/IPUSH4Core.sol";

/// @title PUSH4TestBase
/// @notice Base test contract that deploys PUSH4 contracts to deterministic CREATE2 addresses
/// @dev The PUSH4 contract has hardcoded addresses for PUSH4Core (0x00000063266aAAeDD489e4956153855626E44061)
///      Tests must deploy PUSH4Core to this address for Executed mode to work properly
abstract contract PUSH4TestBase is Test {
    // Deterministic addresses from Deploy.s.sol
    address constant PUSH4_ADDRESS = 0x000000630bf663df3ff850DD34a28Fb7D4d52170;
    address constant PUSH4_CORE_ADDRESS = 0x00000063266aAAeDD489e4956153855626E44061;

    PUSH4 public push4;
    PUSH4Core public push4Core;
    PUSH4Renderer public renderer;
    PUSH4RendererMock public rendererMock;
    PUSH4ProxyTemplate public proxyTemplate;

    /// @notice Deploy PUSH4 to its deterministic address using vm.etch
    function _deployPush4() internal {
        // Deploy PUSH4 normally first
        PUSH4 tempPush4 = new PUSH4();

        // Etch the bytecode to the deterministic address
        vm.etch(PUSH4_ADDRESS, address(tempPush4).code);
        push4 = PUSH4(PUSH4_ADDRESS);
    }

    /// @notice Deploy PUSH4Core to its deterministic address
    /// @param owner The owner address for PUSH4Core
    function _deployPush4Core(address owner) internal {
        require(address(push4) != address(0), "PUSH4 must be deployed first");

        // Deploy PUSH4Core normally to get runtime bytecode
        PUSH4Core tempCore = new PUSH4Core(address(push4), owner);

        // Etch the bytecode to the deterministic address
        vm.etch(PUSH4_CORE_ADDRESS, address(tempCore).code);

        // Copy storage slots from temp to deterministic address
        // PUSH4Core storage layout (after inherited contracts):
        // Slot 0: Ownable._owner (address) - packed
        // Slot 1-4: ERC721 internal storage
        // Slot 5: push4 (address)
        // Slot 6: renderer (IPUSH4Renderer)
        // Slot 7: deploymentTimestamp (uint256)
        // Slot 8: mode (Mode enum = uint8) and proxy (address) - could be packed

        // Copy all relevant storage slots
        for (uint256 i = 0; i < 20; i++) {
            bytes32 slot = bytes32(i);
            bytes32 value = vm.load(address(tempCore), slot);
            vm.store(PUSH4_CORE_ADDRESS, slot, value);
        }

        push4Core = PUSH4Core(PUSH4_CORE_ADDRESS);
    }

    /// @notice Deploy PUSH4Renderer
    /// @param width Image width
    /// @param height Image height
    /// @param pixelSize Pixel size
    /// @param metadata Metadata string
    /// @param owner Owner address
    function _deployRenderer(
        uint256 width,
        uint256 height,
        uint256 pixelSize,
        string memory metadata,
        address owner
    )
        internal
    {
        require(address(push4Core) != address(0), "PUSH4Core must be deployed first");
        renderer = new PUSH4Renderer(width, height, pixelSize, push4Core, metadata, owner);
    }

    /// @notice Deploy PUSH4RendererMock (for testing internal functions)
    /// @param width Image width
    /// @param height Image height
    /// @param pixelSize Pixel size
    /// @param metadata Metadata string
    /// @param owner Owner address
    function _deployRendererMock(
        uint256 width,
        uint256 height,
        uint256 pixelSize,
        string memory metadata,
        address owner
    )
        internal
    {
        require(address(push4Core) != address(0), "PUSH4Core must be deployed first");
        rendererMock = new PUSH4RendererMock(width, height, pixelSize, push4Core, metadata, owner);
    }

    /// @notice Deploy PUSH4ProxyTemplate
    function _deployProxyTemplate() internal {
        require(address(push4) != address(0), "PUSH4 must be deployed first");
        require(address(push4Core) != address(0), "PUSH4Core must be deployed first");
        proxyTemplate = new PUSH4ProxyTemplate(address(push4), address(push4Core));
    }

    /// @notice Full setup with all contracts deployed to deterministic addresses
    /// @param owner The owner address for the contracts
    /// @param width Image width
    /// @param height Image height
    /// @param pixelSize Pixel size
    /// @param metadata Metadata string
    function _fullSetup(
        address owner,
        uint256 width,
        uint256 height,
        uint256 pixelSize,
        string memory metadata
    )
        internal
    {
        _deployPush4();
        _deployPush4Core(owner);
        _deployRenderer(width, height, pixelSize, metadata, owner);
        _deployRendererMock(width, height, pixelSize, metadata, owner);
        _deployProxyTemplate();
        push4Core.setRenderer(renderer);
    }
}

