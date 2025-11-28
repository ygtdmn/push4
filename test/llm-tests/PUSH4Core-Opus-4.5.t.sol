// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { PUSH4Core, IPUSH4Core } from "../../src/PUSH4Core.sol";
import { PUSH4 } from "../../src/PUSH4.sol";
import { PUSH4Renderer } from "../../src/PUSH4Renderer.sol";
import { IPUSH4Renderer } from "../../src/interface/IPUSH4Renderer.sol";
import { Test } from "forge-std/Test.sol";

contract PUSH4CoreOpus45Test is Test {
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

    function test_constructor_setsInitialState() public view {
        assertEq(push4Core.push4(), address(push4));
        assertEq(push4Core.owner(), owner);
        assertEq(push4Core.deploymentTimestamp(), block.timestamp);
        assertEq(uint8(push4Core.mode()), uint8(IPUSH4Core.Mode.Carved));
        assertEq(push4Core.proxy(), address(0));
    }

    function test_constructor_TOKEN_ID_isZero() public view {
        assertEq(push4Core.TOKEN_ID(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                                ERC721
    //////////////////////////////////////////////////////////////*/

    function test_name_returnsPUSH4() public view {
        assertEq(push4Core.name(), "PUSH4");
    }

    function test_symbol_returnsPUSH4() public view {
        assertEq(push4Core.symbol(), "PUSH4");
    }

    function test_totalSupply_returnsZero_whenNotMinted() public view {
        assertEq(push4Core.totalSupply(), 0);
    }

    function test_totalSupply_returnsOne_whenMinted() public {
        push4Core.mint(tokenOwner);
        assertEq(push4Core.totalSupply(), 1);
    }

    function test_tokenURI_revertsWhenNotMinted() public {
        vm.expectRevert(IPUSH4Core.NotMinted.selector);
        push4Core.tokenURI(0);
    }

    function test_tokenURI_returnsRendererUri_whenMinted() public {
        push4Core.mint(tokenOwner);
        string memory uri = push4Core.tokenURI(0);
        assertEq(uri, renderer.getMetadataDataUri());
    }

    function test_mint_mintsToAddress() public {
        push4Core.mint(tokenOwner);
        assertEq(push4Core.ownerOf(0), tokenOwner);
    }

    function test_mint_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        push4Core.mint(tokenOwner);
    }

    function test_mint_revertsWhenAlreadyMinted() public {
        push4Core.mint(tokenOwner);
        vm.expectRevert(IPUSH4Core.AlreadyMinted.selector);
        push4Core.mint(alice);
    }

    function test_supportsInterface_ERC721() public view {
        // ERC721 interface ID
        assertTrue(push4Core.supportsInterface(0x80ac58cd));
    }

    function test_supportsInterface_ERC4906() public view {
        // ERC4906 interface ID
        assertTrue(push4Core.supportsInterface(0x49064906));
    }

    function test_supportsInterface_ERC165() public view {
        // ERC165 interface ID
        assertTrue(push4Core.supportsInterface(0x01ffc9a7));
    }

    /*//////////////////////////////////////////////////////////////
                              GRACE PERIOD
    //////////////////////////////////////////////////////////////*/

    function test_inGracePeriod_trueInitially() public view {
        assertTrue(push4Core.inGracePeriod());
    }

    function test_inGracePeriod_trueAtBoundary() public {
        vm.warp(block.timestamp + 60 days);
        assertTrue(push4Core.inGracePeriod());
    }

    function test_inGracePeriod_falseAfterBoundary() public {
        vm.warp(block.timestamp + 60 days + 1);
        assertFalse(push4Core.inGracePeriod());
    }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_setRenderer_setsRenderer() public {
        PUSH4Renderer newRenderer = new PUSH4Renderer(15, 25, 20, push4Core, METADATA, owner);
        push4Core.setRenderer(newRenderer);
        assertEq(address(push4Core.renderer()), address(newRenderer));
    }

    function test_setRenderer_emitsMetadataUpdate() public {
        PUSH4Renderer newRenderer = new PUSH4Renderer(15, 25, 20, push4Core, METADATA, owner);
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(0);
        push4Core.setRenderer(newRenderer);
    }

    function test_setRenderer_revertsWhenNotOwner() public {
        PUSH4Renderer newRenderer = new PUSH4Renderer(15, 25, 20, push4Core, METADATA, owner);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        push4Core.setRenderer(newRenderer);
    }

    function test_setRenderer_revertsAfterGracePeriod() public {
        vm.warp(block.timestamp + 60 days + 1);
        PUSH4Renderer newRenderer = new PUSH4Renderer(15, 25, 20, push4Core, METADATA, owner);
        vm.expectRevert(IPUSH4Core.NotInGracePeriod.selector);
        push4Core.setRenderer(newRenderer);
    }

    function test_setPush4_setsPush4Address() public {
        address newPush4 = makeAddr("newPush4");
        push4Core.setPush4(newPush4);
        assertEq(push4Core.push4(), newPush4);
    }

    function test_setPush4_emitsMetadataUpdate() public {
        address newPush4 = makeAddr("newPush4");
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(0);
        push4Core.setPush4(newPush4);
    }

    function test_setPush4_revertsWhenNotOwner() public {
        address newPush4 = makeAddr("newPush4");
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        push4Core.setPush4(newPush4);
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

    function test_setMode_setsMode() public {
        push4Core.mint(tokenOwner);
        vm.prank(tokenOwner);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        assertEq(uint8(push4Core.mode()), uint8(IPUSH4Core.Mode.Executed));
    }

    function test_setMode_emitsMetadataUpdate() public {
        push4Core.mint(tokenOwner);
        vm.prank(tokenOwner);
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(0);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
    }

    function test_setMode_emitsModeSet() public {
        push4Core.mint(tokenOwner);
        vm.prank(tokenOwner);
        vm.expectEmit(true, true, true, true);
        emit ModeSet(IPUSH4Core.Mode.Executed);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
    }

    function test_setMode_revertsWhenNotTokenOwner() public {
        push4Core.mint(tokenOwner);
        vm.prank(alice);
        vm.expectRevert(IPUSH4Core.NotTokenOwner.selector);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
    }

    function test_setMode_revertsWhenNotMinted() public {
        vm.expectRevert(IPUSH4Core.NotTokenOwner.selector);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
    }

    function test_setProxy_setsProxy() public {
        push4Core.mint(tokenOwner);
        address proxyAddress = makeAddr("proxy");
        vm.prank(tokenOwner);
        push4Core.setProxy(proxyAddress);
        assertEq(push4Core.proxy(), proxyAddress);
    }

    function test_setProxy_emitsMetadataUpdate() public {
        push4Core.mint(tokenOwner);
        address proxyAddress = makeAddr("proxy");
        vm.prank(tokenOwner);
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(0);
        push4Core.setProxy(proxyAddress);
    }

    function test_setProxy_emitsProxySet() public {
        push4Core.mint(tokenOwner);
        address proxyAddress = makeAddr("proxy");
        vm.prank(tokenOwner);
        vm.expectEmit(true, true, true, true);
        emit ProxySet(proxyAddress);
        push4Core.setProxy(proxyAddress);
    }

    function test_setProxy_revertsWhenNotTokenOwner() public {
        push4Core.mint(tokenOwner);
        address proxyAddress = makeAddr("proxy");
        vm.prank(alice);
        vm.expectRevert(IPUSH4Core.NotTokenOwner.selector);
        push4Core.setProxy(proxyAddress);
    }

    function test_setProxy_revertsWhenNotMinted() public {
        address proxyAddress = makeAddr("proxy");
        vm.expectRevert(IPUSH4Core.NotTokenOwner.selector);
        push4Core.setProxy(proxyAddress);
    }

    /*//////////////////////////////////////////////////////////////
                               SCULPTURE
    //////////////////////////////////////////////////////////////*/

    function test_title_returnsPUSH4() public view {
        assertEq(push4Core.title(), "PUSH4");
    }

    function test_text_returnsCarved_whenModeIsCarved() public {
        push4Core.mint(tokenOwner);
        assertEq(push4Core.text(), "Representing as Carved");
    }

    function test_text_returnsCarved_whenProxyIsZero() public {
        push4Core.mint(tokenOwner);
        vm.prank(tokenOwner);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        // proxy is still address(0)
        assertEq(push4Core.text(), "Representing as Carved");
    }

    function test_text_returnsExecuted_whenModeIsExecutedAndProxySet() public {
        push4Core.mint(tokenOwner);
        address proxyAddress = makeAddr("proxy");
        vm.startPrank(tokenOwner);
        push4Core.setProxy(proxyAddress);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        vm.stopPrank();
        assertEq(push4Core.text(), "Representing as Executed");
    }

    function test_urls_returnsSvgDataUri() public {
        push4Core.mint(tokenOwner);
        string[] memory urls = push4Core.urls();
        assertEq(urls.length, 1);
        assertEq(urls[0], renderer.getSvgDataUri());
    }

    function test_authors_returnsOneAuthor_whenCarvedMode() public {
        push4Core.mint(tokenOwner);
        string[] memory authorsArr = push4Core.authors();
        assertEq(authorsArr.length, 1);
        assertEq(authorsArr[0], "Yigit Duman");
    }

    function test_authors_returnsTwoAuthors_whenExecutedModeWithProxy() public {
        push4Core.mint(tokenOwner);
        address proxyAddress = makeAddr("proxy");
        vm.startPrank(tokenOwner);
        push4Core.setProxy(proxyAddress);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        vm.stopPrank();

        string[] memory authorsArr = push4Core.authors();
        assertEq(authorsArr.length, 2);
        assertEq(authorsArr[0], "Yigit Duman");
        // Second author is the checksummed address of the token owner
    }

    function test_authors_returnsOneAuthor_whenExecutedModeWithoutProxy() public {
        push4Core.mint(tokenOwner);
        vm.prank(tokenOwner);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        // proxy is still address(0)

        string[] memory authorsArr = push4Core.authors();
        assertEq(authorsArr.length, 1);
        assertEq(authorsArr[0], "Yigit Duman");
    }

    function test_addresses_returnsOneAddress_whenCarvedMode() public {
        push4Core.mint(tokenOwner);
        address[] memory addrs = push4Core.addresses();
        assertEq(addrs.length, 1);
        assertEq(addrs[0], address(push4));
    }

    function test_addresses_returnsTwoAddresses_whenExecutedModeWithProxy() public {
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

    function test_addresses_returnsOneAddress_whenExecutedModeWithoutProxy() public {
        push4Core.mint(tokenOwner);
        vm.prank(tokenOwner);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        // proxy is still address(0)

        address[] memory addrs = push4Core.addresses();
        assertEq(addrs.length, 1);
        assertEq(addrs[0], address(push4));
    }
}

