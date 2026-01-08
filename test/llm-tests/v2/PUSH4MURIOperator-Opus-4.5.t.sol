// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";
import { PUSH4MURIOperator } from "../../../src/PUSH4MURIOperator.sol";
import { PUSH4OrchestratorProxy } from "../../../src/PUSH4OrchestratorProxy.sol";
import { PUSH4RendererV2 } from "../../../src/PUSH4RendererV2.sol";
import { IPUSH4OrchestratorProxy } from "../../../src/interface/IPUSH4OrchestratorProxy.sol";
import { IPUSH4RendererV2 } from "../../../src/interface/IPUSH4RendererV2.sol";
import { IPUSH4Proxy } from "../../../src/interface/IPUSH4Proxy.sol";
import { IMURIProtocol } from "../../../src/interface/IMURIProtocol.sol";
import { IMURIProtocolCreator } from "../../../src/interface/IMURIProtocolCreator.sol";
import { PUSH4Core, IPUSH4Core } from "../../../src/PUSH4Core.sol";
import { PUSH4 } from "../../../src/PUSH4.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @notice Mock MURI Protocol for testing operator
contract MockMURIProtocolForOperator is IMURIProtocol {
    bool public initializeCalled;
    address public lastInitContract;
    uint256 public lastInitTokenId;

    function getCombinedArtworkUris(address, uint256) external pure returns (string memory) {
        return "mock://combined";
    }

    function renderRawHTML(address, uint256) external pure returns (string memory) {
        return "<html>Mock</html>";
    }

    function initializeTokenData(
        address contractAddress,
        uint256 tokenId,
        InitConfig calldata,
        bytes[] calldata,
        string[] calldata
    )
        external
    {
        initializeCalled = true;
        lastInitContract = contractAddress;
        lastInitTokenId = tokenId;
    }

    function registerContract(address, address) external override { }

    function isContractOperator(address, address) external pure override returns (bool) {
        return true;
    }
    function updateMetadata(address, uint256, string calldata) external override { }
    function updateHtmlTemplate(address, uint256, string[] calldata, bool) external override { }
    function updateThumbnail(address, uint256, Thumbnail calldata, bytes[] calldata) external override { }
    function revokeArtistPermissions(address, uint256, bool, bool, bool, bool, bool, bool, bool) external override { }
    function revokeAllArtistPermissions(address, uint256) external override { }
    function addArtworkUris(address, uint256, string[] calldata) external override { }
    function removeArtworkUris(address, uint256, uint256[] calldata) external override { }
    function setSelectedUri(address, uint256, uint256) external override { }
    function setSelectedThumbnailUri(address, uint256, uint256) external override { }
    function setDisplayMode(address, uint256, DisplayMode) external override { }
    function setDefaultHtmlTemplate(string[] calldata, bool) external override { }

    function getDefaultHtmlTemplate() external pure override returns (string memory) {
        return "";
    }

    function renderImage(address, uint256) external pure override returns (string memory) {
        return "";
    }

    function renderRawImage(address, uint256) external pure override returns (bytes memory) {
        return "";
    }

    function renderHTML(address, uint256) external pure override returns (string memory) {
        return "";
    }

    function renderMetadata(address, uint256) external pure override returns (string memory) {
        return "";
    }

    function getArtistArtworkUris(address, uint256) external pure override returns (string[] memory) {
        return new string[](0);
    }

    function getCollectorArtworkUris(address, uint256) external pure override returns (string[] memory) {
        return new string[](0);
    }

    function getThumbnailUris(address, uint256) external pure override returns (string[] memory) {
        return new string[](0);
    }

    function getPermissions(address, uint256) external pure override returns (Permissions memory) {
        return Permissions(0);
    }

    function getArtwork(address, uint256) external pure override returns (Artwork memory) {
        return Artwork(new string[](0), new string[](0), "", "", false, 0);
    }

    function getThumbnailInfo(address, uint256) external pure override returns (ThumbnailKind, uint256) {
        return (ThumbnailKind.OFF_CHAIN, 0);
    }

    function getTokenHtmlTemplate(address, uint256) external pure override returns (string memory) {
        return "";
    }
}

/// @notice Mock proxy for testing creator checks
contract MockProxyForOperator is IPUSH4Proxy {
    Creator private _creator;

    constructor(string memory creatorName, address creatorWallet) {
        _creator = Creator({ name: creatorName, wallet: creatorWallet });
    }

    function execute(bytes4 selector) external pure returns (bytes4) {
        return selector;
    }

    function title() external pure returns (string memory) {
        return "Mock Proxy";
    }

    function description() external pure returns (string memory) {
        return "Mock";
    }

    function creator() external view returns (Creator memory) {
        return _creator;
    }
}

/// @notice Mock ERC721 for testing token ownership
contract MockERC721 {
    mapping(uint256 => address) private _owners;

    function setOwner(uint256 tokenId, address ownerAddr) external {
        _owners[tokenId] = ownerAddr;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address ownerAddr = _owners[tokenId];
        require(ownerAddr != address(0), "Token does not exist");
        return ownerAddr;
    }
}

contract PUSH4MURIOperatorOpus45Test is Test {
    PUSH4MURIOperator public muriOperator;
    PUSH4OrchestratorProxy public orchestrator;
    PUSH4RendererV2 public rendererV2;
    PUSH4Core public push4Core;
    PUSH4 public push4;
    MockMURIProtocolForOperator public mockMuri;
    MockProxyForOperator public mockProxy;
    MockERC721 public mockERC721;

    address public owner = address(this);
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public creatorWallet = makeAddr("creatorWallet");
    address public tokenOwner = makeAddr("tokenOwner");

    uint256 constant WIDTH = 15;
    uint256 constant HEIGHT = 25;
    uint256 constant PIXEL_SIZE = 20;
    uint256 constant BLOCK_INTERVAL = 100;
    uint256 constant TOKEN_ID = 0;

    string constant METADATA = '"name": "PUSH4 MURI Operator Test"';

    // Deterministic addresses
    address constant PUSH4_ADDRESS = 0x000000630bf663df3ff850DD34a28Fb7D4d52170;
    address constant PUSH4_CORE_ADDRESS = 0x00000063266aAAeDD489e4956153855626E44061;

    event OrchestratorUpdated(address indexed orchestrator);
    event RendererUpdated(address indexed renderer);
    event MURIProtocolUpdated(address indexed muriProtocol);

    function setUp() public {
        // Deploy PUSH4 to deterministic address
        PUSH4 tempPush4 = new PUSH4();
        vm.etch(PUSH4_ADDRESS, address(tempPush4).code);
        push4 = PUSH4(PUSH4_ADDRESS);

        // Deploy PUSH4Core to deterministic address
        PUSH4Core tempCore = new PUSH4Core(address(push4), owner);
        vm.etch(PUSH4_CORE_ADDRESS, address(tempCore).code);
        for (uint256 i = 0; i < 20; i++) {
            bytes32 slot = bytes32(i);
            bytes32 value = vm.load(address(tempCore), slot);
            vm.store(PUSH4_CORE_ADDRESS, slot, value);
        }
        push4Core = PUSH4Core(PUSH4_CORE_ADDRESS);

        // Deploy RendererV2
        rendererV2 = new PUSH4RendererV2(WIDTH, HEIGHT, PIXEL_SIZE, push4Core, METADATA, BLOCK_INTERVAL, owner);

        // Mint token ID 0 to tokenOwner
        push4Core.mint(tokenOwner);

        // Deploy orchestrator
        orchestrator =
            new PUSH4OrchestratorProxy(owner, IPUSH4RendererV2(address(rendererV2)), IERC721(address(push4Core)));

        // Deploy mock MURI
        mockMuri = new MockMURIProtocolForOperator();

        // Deploy mock proxy
        mockProxy = new MockProxyForOperator("Test Creator", creatorWallet);

        // Deploy mock ERC721
        mockERC721 = new MockERC721();

        // Deploy MURI operator
        muriOperator =
            new PUSH4MURIOperator(IPUSH4OrchestratorProxy(address(orchestrator)), rendererV2, mockMuri, owner);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsOrchestrator() public view {
        assertEq(address(muriOperator.orchestrator()), address(orchestrator));
    }

    function test_constructor_setsRenderer() public view {
        assertEq(address(muriOperator.renderer()), address(rendererV2));
    }

    function test_constructor_setsMuriProtocol() public view {
        assertEq(address(muriOperator.muriProtocol()), address(mockMuri));
    }

    function test_constructor_setsOwner() public view {
        assertEq(muriOperator.owner(), owner);
    }

    /*//////////////////////////////////////////////////////////////
                          SET ORCHESTRATOR
    //////////////////////////////////////////////////////////////*/

    function test_setOrchestrator_updatesAddress() public {
        PUSH4OrchestratorProxy newOrchestrator =
            new PUSH4OrchestratorProxy(owner, IPUSH4RendererV2(address(rendererV2)), IERC721(address(push4Core)));
        muriOperator.setOrchestrator(IPUSH4OrchestratorProxy(address(newOrchestrator)));
        assertEq(address(muriOperator.orchestrator()), address(newOrchestrator));
    }

    function test_setOrchestrator_emitsEvent() public {
        PUSH4OrchestratorProxy newOrchestrator =
            new PUSH4OrchestratorProxy(owner, IPUSH4RendererV2(address(rendererV2)), IERC721(address(push4Core)));
        vm.expectEmit(true, true, true, true);
        emit OrchestratorUpdated(address(newOrchestrator));
        muriOperator.setOrchestrator(IPUSH4OrchestratorProxy(address(newOrchestrator)));
    }

    function test_setOrchestrator_revertsWhenNotOwner() public {
        PUSH4OrchestratorProxy newOrchestrator =
            new PUSH4OrchestratorProxy(owner, IPUSH4RendererV2(address(rendererV2)), IERC721(address(push4Core)));
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        muriOperator.setOrchestrator(IPUSH4OrchestratorProxy(address(newOrchestrator)));
    }

    function test_setOrchestrator_allowsZeroAddress() public {
        muriOperator.setOrchestrator(IPUSH4OrchestratorProxy(address(0)));
        assertEq(address(muriOperator.orchestrator()), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                            SET RENDERER
    //////////////////////////////////////////////////////////////*/

    function test_setRenderer_updatesAddress() public {
        PUSH4RendererV2 newRenderer =
            new PUSH4RendererV2(WIDTH, HEIGHT, PIXEL_SIZE, push4Core, METADATA, BLOCK_INTERVAL, owner);
        muriOperator.setRenderer(newRenderer);
        assertEq(address(muriOperator.renderer()), address(newRenderer));
    }

    function test_setRenderer_emitsEvent() public {
        PUSH4RendererV2 newRenderer =
            new PUSH4RendererV2(WIDTH, HEIGHT, PIXEL_SIZE, push4Core, METADATA, BLOCK_INTERVAL, owner);
        vm.expectEmit(true, true, true, true);
        emit RendererUpdated(address(newRenderer));
        muriOperator.setRenderer(newRenderer);
    }

    function test_setRenderer_revertsWhenNotOwner() public {
        PUSH4RendererV2 newRenderer =
            new PUSH4RendererV2(WIDTH, HEIGHT, PIXEL_SIZE, push4Core, METADATA, BLOCK_INTERVAL, owner);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        muriOperator.setRenderer(newRenderer);
    }

    /*//////////////////////////////////////////////////////////////
                          SET MURI PROTOCOL
    //////////////////////////////////////////////////////////////*/

    function test_setMURIProtocol_updatesAddress() public {
        MockMURIProtocolForOperator newMuri = new MockMURIProtocolForOperator();
        muriOperator.setMURIProtocol(address(newMuri));
        assertEq(address(muriOperator.muriProtocol()), address(newMuri));
    }

    function test_setMURIProtocol_emitsEvent() public {
        MockMURIProtocolForOperator newMuri = new MockMURIProtocolForOperator();
        vm.expectEmit(true, true, true, true);
        emit MURIProtocolUpdated(address(newMuri));
        muriOperator.setMURIProtocol(address(newMuri));
    }

    function test_setMURIProtocol_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        muriOperator.setMURIProtocol(address(mockMuri));
    }

    function test_setMURIProtocol_allowsZeroAddress() public {
        muriOperator.setMURIProtocol(address(0));
        assertEq(address(muriOperator.muriProtocol()), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                            IS TOKEN OWNER
    //////////////////////////////////////////////////////////////*/

    function test_isTokenOwner_returnsTrueForOrchestratorOwner() public view {
        // owner is the orchestrator owner
        bool result = muriOperator.isTokenOwner(address(mockERC721), owner, TOKEN_ID);
        assertTrue(result);
    }

    function test_isTokenOwner_returnsTrueForCreator() public {
        // Register the mock proxy with the orchestrator
        orchestrator.registerProxy(mockProxy);

        // creatorWallet is the creator in mockProxy
        bool result = muriOperator.isTokenOwner(address(mockERC721), creatorWallet, TOKEN_ID);
        assertTrue(result);
    }

    function test_isTokenOwner_returnsTrueForERC721Owner() public {
        // Set up mock ERC721 ownership
        mockERC721.setOwner(TOKEN_ID, tokenOwner);

        bool result = muriOperator.isTokenOwner(address(mockERC721), tokenOwner, TOKEN_ID);
        assertTrue(result);
    }

    function test_isTokenOwner_returnsFalseForNonOwner() public view {
        bool result = muriOperator.isTokenOwner(address(mockERC721), alice, TOKEN_ID);
        assertFalse(result);
    }

    function test_isTokenOwner_handlesERC721RevertGracefully() public view {
        // mockERC721 will revert for non-existent token (address(0) owner)
        // Should not revert, just return false
        bool result = muriOperator.isTokenOwner(address(mockERC721), alice, 999);
        assertFalse(result);
    }

    function test_isTokenOwner_worksWithZeroOrchestrator() public {
        // Set orchestrator to zero
        muriOperator.setOrchestrator(IPUSH4OrchestratorProxy(address(0)));

        // Set up mock ERC721 ownership
        mockERC721.setOwner(TOKEN_ID, tokenOwner);

        // Should still check ERC721 ownership
        bool result = muriOperator.isTokenOwner(address(mockERC721), tokenOwner, TOKEN_ID);
        assertTrue(result);

        // Non-owner should return false
        result = muriOperator.isTokenOwner(address(mockERC721), alice, TOKEN_ID);
        assertFalse(result);
    }

    function test_isTokenOwner_checksOrchestratorOwnerFirst() public view {
        // Even if ERC721 doesn't have the owner, orchestrator owner should return true
        bool result = muriOperator.isTokenOwner(address(mockERC721), owner, 999);
        assertTrue(result);
    }

    function test_isTokenOwner_checksCreatorSecond() public {
        orchestrator.registerProxy(mockProxy);

        // Even if ERC721 doesn't have the owner, creator should return true
        bool result = muriOperator.isTokenOwner(address(mockERC721), creatorWallet, 999);
        assertTrue(result);
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZE TOKEN DATA
    //////////////////////////////////////////////////////////////*/

    function test_initializeTokenData_forwardsToMuri() public {
        IMURIProtocol.InitConfig memory config = IMURIProtocol.InitConfig({
            metadata: "test",
            displayMode: IMURIProtocol.DisplayMode.HTML,
            artwork: IMURIProtocol.Artwork({
                artistUris: new string[](0),
                collectorUris: new string[](0),
                selectedArtistUriIndex: 0,
                mimeType: "text/html",
                fileHash: "",
                isAnimationUri: true
            }),
            permissions: IMURIProtocol.Permissions({ flags: 0 }),
            thumbnail: IMURIProtocol.Thumbnail({
                kind: IMURIProtocol.ThumbnailKind.ON_CHAIN,
                onChain: IMURIProtocol.OnChainThumbnail({
                    chunks: new address[](0), mimeType: "image/png", zipped: false
                }),
                offChain: IMURIProtocol.OffChainThumbnail({ uris: new string[](0), selectedUriIndex: 0 })
            }),
            htmlTemplate: IMURIProtocol.HtmlTemplate({ chunks: new address[](0), zipped: false })
        });

        bytes[] memory thumbnailChunks = new bytes[](0);
        string[] memory htmlTemplateChunks = new string[](0);

        muriOperator.initializeTokenData(address(push4Core), TOKEN_ID, config, thumbnailChunks, htmlTemplateChunks);

        assertTrue(mockMuri.initializeCalled());
        assertEq(mockMuri.lastInitContract(), address(push4Core));
        assertEq(mockMuri.lastInitTokenId(), TOKEN_ID);
    }

    function test_initializeTokenData_revertsWhenNotOwner() public {
        IMURIProtocol.InitConfig memory config = IMURIProtocol.InitConfig({
            metadata: "test",
            displayMode: IMURIProtocol.DisplayMode.HTML,
            artwork: IMURIProtocol.Artwork({
                artistUris: new string[](0),
                collectorUris: new string[](0),
                selectedArtistUriIndex: 0,
                mimeType: "text/html",
                fileHash: "",
                isAnimationUri: true
            }),
            permissions: IMURIProtocol.Permissions({ flags: 0 }),
            thumbnail: IMURIProtocol.Thumbnail({
                kind: IMURIProtocol.ThumbnailKind.ON_CHAIN,
                onChain: IMURIProtocol.OnChainThumbnail({
                    chunks: new address[](0), mimeType: "image/png", zipped: false
                }),
                offChain: IMURIProtocol.OffChainThumbnail({ uris: new string[](0), selectedUriIndex: 0 })
            }),
            htmlTemplate: IMURIProtocol.HtmlTemplate({ chunks: new address[](0), zipped: false })
        });

        bytes[] memory thumbnailChunks = new bytes[](0);
        string[] memory htmlTemplateChunks = new string[](0);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        muriOperator.initializeTokenData(address(push4Core), TOKEN_ID, config, thumbnailChunks, htmlTemplateChunks);
    }

    /*//////////////////////////////////////////////////////////////
                          SUPPORTS INTERFACE
    //////////////////////////////////////////////////////////////*/

    function test_supportsInterface_IMURIProtocolCreator() public view {
        bytes4 interfaceId = type(IMURIProtocolCreator).interfaceId;
        assertTrue(muriOperator.supportsInterface(interfaceId));
    }

    function test_supportsInterface_IERC165() public view {
        bytes4 interfaceId = type(IERC165).interfaceId;
        assertTrue(muriOperator.supportsInterface(interfaceId));
    }

    function test_supportsInterface_returnsFalseForUnknown() public view {
        bytes4 unknownInterfaceId = bytes4(0x12345678);
        assertFalse(muriOperator.supportsInterface(unknownInterfaceId));
    }

    function test_supportsInterface_returnsFalseForERC721() public view {
        bytes4 erc721InterfaceId = type(IERC721).interfaceId;
        assertFalse(muriOperator.supportsInterface(erc721InterfaceId));
    }

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    function test_transferOwnership_succeeds() public {
        muriOperator.transferOwnership(alice);
        assertEq(muriOperator.owner(), alice);
    }

    function test_transferOwnership_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        muriOperator.transferOwnership(bob);
    }

    function test_renounceOwnership_succeeds() public {
        muriOperator.renounceOwnership();
        assertEq(muriOperator.owner(), address(0));
    }

    function test_renounceOwnership_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        muriOperator.renounceOwnership();
    }
}

