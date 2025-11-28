// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";
import { PUSH4Core } from "../../src/PUSH4Core.sol";
import { IPUSH4Core } from "../../src/interface/IPUSH4Core.sol";
import { IPUSH4Renderer } from "../../src/interface/IPUSH4Renderer.sol";
import { LibString } from "solady/utils/LibString.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MockRenderer is IPUSH4Renderer {
    function width() external pure returns (uint256) { return 0; }
    function height() external pure returns (uint256) { return 0; }
    function pixelSize() external pure returns (uint256) { return 0; }
    function push4Core() external pure returns (IPUSH4Core) { return IPUSH4Core(address(0)); }
    function getPixels(IPUSH4Core.Mode) external pure returns (bytes4[] memory) { return new bytes4[](0); }
    function getSvg() external pure returns (string memory) { return ""; }
    function getSvgDataUri() external pure returns (string memory) { return "mock_svg_uri"; }
    function getMetadata() external pure returns (string memory) { return ""; }
    function getMetadataDataUri() external pure returns (string memory) { return "mock_metadata_uri"; }
    function getKnownFalseSelectors() external pure returns (bytes4[11] memory) { return [bytes4(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]; }
    function isKnownFalseSelector(bytes4) external pure returns (bool) { return false; }
}

contract PUSH4CoreGemini3ProTest is Test {
    PUSH4Core public core;
    MockRenderer public renderer;
    
    address public owner = address(0x1);
    address public user = address(0x2);
    address public push4Addr = address(0x3);
    address public proxyAddr = address(0x4);
    address public otherUser = address(0x5);

    event MetadataUpdate(uint256 _tokenId);
    event ModeSet(IPUSH4Core.Mode _mode);
    event ProxySet(address _proxy);

    function setUp() public {
        vm.label(owner, "Owner");
        vm.label(user, "User");
        vm.label(push4Addr, "Push4");
        vm.label(proxyAddr, "Proxy");

        renderer = new MockRenderer();
        
        // Deploy PUSH4Core
        // constructor(address _push4, address _owner)
        core = new PUSH4Core(push4Addr, owner);

        // Set renderer in grace period
        vm.prank(owner);
        core.setRenderer(renderer);
    }

    function test_InitialState() public view {
        assertEq(core.name(), "PUSH4");
        assertEq(core.symbol(), "PUSH4");
        assertEq(core.totalSupply(), 0);
        assertEq(core.owner(), owner);
        assertEq(core.push4(), push4Addr);
        assertEq(address(core.renderer()), address(renderer));
        assertEq(core.deploymentTimestamp(), block.timestamp);
        assertEq(uint256(core.mode()), uint256(IPUSH4Core.Mode.Carved)); // Default enum value 0
        assertEq(core.proxy(), address(0));
        assertTrue(core.inGracePeriod());
    }

    function test_Mint() public {
        vm.startPrank(owner);
        
        core.mint(user);
        
        assertEq(core.ownerOf(0), user);
        assertEq(core.totalSupply(), 1);
        assertEq(core.balanceOf(user), 1);

        // Try minting again
        vm.expectRevert(IPUSH4Core.AlreadyMinted.selector);
        core.mint(otherUser);
        
        vm.stopPrank();
    }

    function test_Mint_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        core.mint(user);
    }

    function test_TokenURI() public {
        // Revert when not minted
        vm.expectRevert(IPUSH4Core.NotMinted.selector);
        core.tokenURI(0);

        vm.prank(owner);
        core.mint(user);

        assertEq(core.tokenURI(0), "mock_metadata_uri");
    }

    function test_SetRenderer() public {
        MockRenderer newRenderer = new MockRenderer();
        
        vm.startPrank(owner);
        
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(0);
        core.setRenderer(newRenderer);
        
        assertEq(address(core.renderer()), address(newRenderer));
        vm.stopPrank();
    }

    function test_SetRenderer_OnlyOwner() public {
        MockRenderer newRenderer = new MockRenderer();
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        core.setRenderer(newRenderer);
    }

    function test_SetRenderer_GracePeriod() public {
        vm.warp(block.timestamp + 61 days);
        assertFalse(core.inGracePeriod());
        
        MockRenderer newRenderer = new MockRenderer();
        vm.prank(owner);
        vm.expectRevert(IPUSH4Core.NotInGracePeriod.selector);
        core.setRenderer(newRenderer);
    }

    function test_SetPush4() public {
        address newPush4 = address(0x99);
        
        vm.startPrank(owner);
        
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(0);
        core.setPush4(newPush4);
        
        assertEq(core.push4(), newPush4);
        vm.stopPrank();
    }

    function test_SetPush4_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        core.setPush4(address(0x99));
    }

    function test_SetPush4_GracePeriod() public {
        vm.warp(block.timestamp + 61 days);
        
        vm.prank(owner);
        vm.expectRevert(IPUSH4Core.NotInGracePeriod.selector);
        core.setPush4(address(0x99));
    }

    function test_SetMode() public {
        vm.prank(owner);
        core.mint(user);

        vm.startPrank(user);
        
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(0);
        vm.expectEmit(true, true, true, true);
        emit ModeSet(IPUSH4Core.Mode.Executed);
        
        core.setMode(IPUSH4Core.Mode.Executed);
        assertEq(uint256(core.mode()), uint256(IPUSH4Core.Mode.Executed));
        
        vm.stopPrank();
    }

    function test_SetMode_NotTokenOwner() public {
        vm.prank(owner);
        core.mint(user);

        vm.prank(owner); // Owner is not token owner
        vm.expectRevert(IPUSH4Core.NotTokenOwner.selector);
        core.setMode(IPUSH4Core.Mode.Executed);
    }

    function test_SetProxy() public {
        vm.prank(owner);
        core.mint(user);

        vm.startPrank(user);
        
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(0);
        vm.expectEmit(true, true, true, true);
        emit ProxySet(proxyAddr);
        
        core.setProxy(proxyAddr);
        assertEq(core.proxy(), proxyAddr);
        
        vm.stopPrank();
    }

    function test_SetProxy_NotTokenOwner() public {
        vm.prank(owner);
        core.mint(user);

        vm.prank(owner);
        vm.expectRevert(IPUSH4Core.NotTokenOwner.selector);
        core.setProxy(proxyAddr);
    }

    function test_Sculpture_Views_Carved() public {
        vm.prank(owner);
        core.mint(user);
        // Default mode is Carved

        assertEq(core.title(), "PUSH4");
        
        string[] memory authors = core.authors();
        assertEq(authors.length, 1);
        assertEq(authors[0], "Yigit Duman");
        
        address[] memory addrs = core.addresses();
        assertEq(addrs.length, 1);
        assertEq(addrs[0], push4Addr);

        string[] memory urls = core.urls();
        assertEq(urls.length, 1);
        assertEq(urls[0], "mock_svg_uri");
    }

    function test_Sculpture_Views_Executed() public {
        vm.prank(owner);
        core.mint(user);

        vm.startPrank(user);
        core.setMode(IPUSH4Core.Mode.Executed);
        core.setProxy(proxyAddr);
        vm.stopPrank();

        // Check text
        assertEq(core.text(), "Representing as Executed");

        // Check addresses
        address[] memory addrs = core.addresses();
        assertEq(addrs.length, 2);
        assertEq(addrs[0], push4Addr);
        assertEq(addrs[1], proxyAddr);

        // Check authors
        string[] memory authors = core.authors();
        assertEq(authors.length, 2);
        assertEq(authors[0], "Yigit Duman");
        assertEq(authors[1], LibString.toHexStringChecksummed(user));
    }

    function test_SupportsInterface() public view {
        assertTrue(core.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(core.supportsInterface(0x5b5e139f)); // ERC721Metadata
        assertFalse(core.supportsInterface(0x780e9d63)); // ERC721Enumerable (not supported)
        
        assertTrue(core.supportsInterface(0x49064906)); // ERC4906
    }
}

