// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { PUSH4Core, IPUSH4Core } from "../src/PUSH4Core.sol";
import { PUSH4 } from "../src/PUSH4.sol";
import { PUSH4Renderer } from "../src/PUSH4Renderer.sol";
import { IPUSH4Renderer } from "../src/interface/IPUSH4Renderer.sol";
import { Test } from "forge-std/Test.sol";
import { LibString } from "solady/utils/LibString.sol";

contract PUSH4CoreTest is Test {
    PUSH4Core public push4Core;
    PUSH4Renderer public renderer;
    PUSH4 public push4;

    address public owner = address(this);
    address public tokenOwner = makeAddr("tokenOwner");
    address public alice = makeAddr("alice");

    string constant METADATA =
        unicode"\"name\": \"PUSH4\",\"description\": \"A heavily compressed and dithered down version of Barnett Newman's Onement I, encoded in 375 smart contract function selectors.\"";

    event MetadataUpdate(uint256 _tokenId);
    event ModeSet(IPUSH4Core.Mode _mode);
    event ProxySet(address _proxy);

    function setUp() public {
        push4 = new PUSH4();
        push4Core = new PUSH4Core(address(push4), owner);
        renderer = new PUSH4Renderer(15, 25, 20, push4Core, METADATA, owner);
        push4Core.setRenderer(renderer);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_constructor_deploymentTimestamp_matchesBlockTimestamp() public {
        uint256 currentTimestamp = block.timestamp;
        PUSH4Core newCore = new PUSH4Core(address(push4), owner);
        assertEq(newCore.deploymentTimestamp(), currentTimestamp);
    }

    /*//////////////////////////////////////////////////////////////
                           ERC721 / TOKEN URI
    //////////////////////////////////////////////////////////////*/

    function test_tokenURI_revertsWhenNotMinted() public {
        vm.expectRevert(IPUSH4Core.NotMinted.selector);
        push4Core.tokenURI(0);
    }

    function test_tokenURI_returnsRendererMetadataUri() public {
        push4Core.mint(tokenOwner);
        string memory uri = push4Core.tokenURI(0);
        assertEq(uri, renderer.getMetadataDataUri());
    }

    function test_totalSupply_changesWhenMinted() public {
        assertEq(push4Core.totalSupply(), 0);
        push4Core.mint(tokenOwner);
        assertEq(push4Core.totalSupply(), 1);
    }

    /*//////////////////////////////////////////////////////////////
                                MINTING
    //////////////////////////////////////////////////////////////*/

    function test_mint_revertsWhenAlreadyMinted() public {
        push4Core.mint(tokenOwner);
        vm.expectRevert(IPUSH4Core.AlreadyMinted.selector);
        push4Core.mint(alice);
    }

    function test_mint_mintsToTokenIdZero() public {
        push4Core.mint(tokenOwner);
        assertEq(push4Core.ownerOf(0), tokenOwner);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERFACE SUPPORT
    //////////////////////////////////////////////////////////////*/

    function test_supportsInterface_ERC4906() public view {
        assertTrue(push4Core.supportsInterface(0x49064906));
    }

    /*//////////////////////////////////////////////////////////////
                              GRACE PERIOD
    //////////////////////////////////////////////////////////////*/

    function test_inGracePeriod_returnsFalseAfter60Days() public {
        vm.warp(block.timestamp + 60 days + 1);
        assertFalse(push4Core.inGracePeriod());
    }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_setRenderer_revertsWhenNotOwner() public {
        PUSH4Renderer newRenderer = new PUSH4Renderer(15, 25, 20, push4Core, METADATA, owner);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        push4Core.setRenderer(newRenderer);
    }

    function test_setPush4_revertsWhenNotOwner() public {
        address newPush4 = makeAddr("newPush4");
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        push4Core.setPush4(newPush4);
    }

    function test_setRenderer_revertsAfterGracePeriod() public {
        vm.warp(block.timestamp + 60 days + 1);
        PUSH4Renderer newRenderer = new PUSH4Renderer(15, 25, 20, push4Core, METADATA, owner);
        vm.expectRevert(IPUSH4Core.NotInGracePeriod.selector);
        push4Core.setRenderer(newRenderer);
    }

    function test_setPush4_revertsAfterGracePeriod() public {
        vm.warp(block.timestamp + 60 days + 1);
        address newPush4 = makeAddr("newPush4");
        vm.expectRevert(IPUSH4Core.NotInGracePeriod.selector);
        push4Core.setPush4(newPush4);
    }

    /*//////////////////////////////////////////////////////////////
                         TOKEN OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_setMode_revertsWhenNotTokenOwner() public {
        push4Core.mint(tokenOwner);
        vm.prank(alice);
        vm.expectRevert(IPUSH4Core.NotTokenOwner.selector);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
    }

    function test_setProxy_revertsWhenNotTokenOwner() public {
        push4Core.mint(tokenOwner);
        address proxyAddress = makeAddr("proxy");
        vm.prank(alice);
        vm.expectRevert(IPUSH4Core.NotTokenOwner.selector);
        push4Core.setProxy(proxyAddress);
    }

    function test_setMode_emitsMetadataUpdate() public {
        push4Core.mint(tokenOwner);
        vm.prank(tokenOwner);
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(0);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
    }

    function test_setProxy_emitsMetadataUpdate() public {
        push4Core.mint(tokenOwner);
        address proxyAddress = makeAddr("proxy");
        vm.prank(tokenOwner);
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(0);
        push4Core.setProxy(proxyAddress);
    }

    function test_setMode_emitsModeSetEvent() public {
        push4Core.mint(tokenOwner);
        vm.prank(tokenOwner);
        vm.expectEmit(true, true, true, true);
        emit ModeSet(IPUSH4Core.Mode.Executed);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
    }

    function test_setProxy_emitsProxySetEvent() public {
        push4Core.mint(tokenOwner);
        address proxyAddress = makeAddr("proxy");
        vm.prank(tokenOwner);
        vm.expectEmit(true, true, true, true);
        emit ProxySet(proxyAddress);
        push4Core.setProxy(proxyAddress);
    }

    /*//////////////////////////////////////////////////////////////
                           SCULPTURE INTERFACE
    //////////////////////////////////////////////////////////////*/

    function test_authors_includesTokenOwnerWallet_whenExecutedWithProxy() public {
        push4Core.mint(tokenOwner);
        address proxyAddress = makeAddr("proxy");
        vm.startPrank(tokenOwner);
        push4Core.setProxy(proxyAddress);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        vm.stopPrank();

        string[] memory authorsArr = push4Core.authors();
        assertEq(authorsArr.length, 2);
        assertEq(authorsArr[0], "Yigit Duman");
        assertEq(authorsArr[1], LibString.toHexStringChecksummed(tokenOwner));
    }

    function test_addresses_includesProxy_whenExecutedWithProxy() public {
        push4Core.mint(tokenOwner);
        address proxyAddress = makeAddr("proxy");
        vm.startPrank(tokenOwner);
        push4Core.setProxy(proxyAddress);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        vm.stopPrank();

        address[] memory addrs = push4Core.addresses();
        assertEq(addrs.length, 2);
        assertEq(addrs[0], address(push4));
        assertEq(addrs[1], proxyAddress);
    }

    function test_urls_returnsRendererSvgDataUri() public view {
        string[] memory urls = push4Core.urls();
        assertEq(urls.length, 1);
        assertEq(urls[0], renderer.getSvgDataUri());
    }

    function test_text_changesWithMode() public {
        push4Core.mint(tokenOwner);

        // Initially in Carved mode
        assertEq(push4Core.text(), "Representing as Carved");

        // Set proxy and mode to Executed
        address proxyAddress = makeAddr("proxy");
        vm.startPrank(tokenOwner);
        push4Core.setProxy(proxyAddress);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        vm.stopPrank();

        assertEq(push4Core.text(), "Representing as Executed");
    }
}

