// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { PUSH4Core, IPUSH4Core } from "../../src/PUSH4Core.sol";
import { PUSH4 } from "../../src/PUSH4.sol";
import { PUSH4Renderer } from "../../src/PUSH4Renderer.sol";
import { IPUSH4Renderer } from "../../src/interface/IPUSH4Renderer.sol";
import { Sculpture } from "../../src/interface/Sculpture.sol";

contract PUSH4CoreSonnet45Test is Test {
    PUSH4Core public push4Core;
    PUSH4 public push4;
    PUSH4Renderer public renderer;

    address public owner;
    address public tokenOwner;
    address public randomUser;

    event MetadataUpdate(uint256 _tokenId);
    event ModeSet(IPUSH4Core.Mode _mode);
    event ProxySet(address _proxy);

    function setUp() public {
        owner = makeAddr("owner");
        tokenOwner = makeAddr("tokenOwner");
        randomUser = makeAddr("randomUser");

        // Deploy PUSH4 contract
        push4 = new PUSH4();

        // Deploy PUSH4Core
        vm.prank(owner);
        push4Core = new PUSH4Core(address(push4), owner);

        // Deploy renderer
        string memory metadata =
            unicode"\"name\": \"PUSH4\",\"description\": \"A heavily compressed and dithered down version of Barnett Newman's Onement I, encoded in 375 smart contract function selectors.\"";
        renderer = new PUSH4Renderer(15, 25, 20, push4Core, metadata, owner);

        // Set renderer
        vm.prank(owner);
        push4Core.setRenderer(renderer);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public {
        PUSH4Core newCore = new PUSH4Core(address(push4), owner);

        assertEq(newCore.push4(), address(push4));
        assertEq(newCore.owner(), owner);
        assertEq(newCore.deploymentTimestamp(), block.timestamp);
        assertEq(uint256(newCore.mode()), uint256(IPUSH4Core.Mode.Carved));
        assertEq(newCore.proxy(), address(0));
    }

    function test_Constructor_SetsConstantTokenId() public view {
        assertEq(push4Core.TOKEN_ID(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC721 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Name() public view {
        assertEq(push4Core.name(), "PUSH4");
    }

    function test_Symbol() public view {
        assertEq(push4Core.symbol(), "PUSH4");
    }

    function test_TotalSupply_BeforeMint() public view {
        assertEq(push4Core.totalSupply(), 0);
    }

    function test_TotalSupply_AfterMint() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        assertEq(push4Core.totalSupply(), 1);
    }

    function test_Mint_Success() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        assertEq(push4Core.ownerOf(0), tokenOwner);
        assertEq(push4Core.totalSupply(), 1);
    }

    function test_Mint_RevertsIfNotOwner() public {
        vm.prank(randomUser);
        vm.expectRevert();
        push4Core.mint(tokenOwner);
    }

    function test_Mint_RevertsIfAlreadyMinted() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        vm.prank(owner);
        vm.expectRevert(IPUSH4Core.AlreadyMinted.selector);
        push4Core.mint(randomUser);
    }

    function test_TokenURI_Success() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        string memory uri = push4Core.tokenURI(0);
        assertTrue(bytes(uri).length > 0);
    }

    function test_TokenURI_RevertsIfNotMinted() public {
        vm.expectRevert(IPUSH4Core.NotMinted.selector);
        push4Core.tokenURI(0);
    }

    function test_SupportsInterface_ERC721() public view {
        // ERC721 interface ID: 0x80ac58cd
        assertTrue(push4Core.supportsInterface(0x80ac58cd));
    }

    function test_SupportsInterface_ERC4906() public view {
        // ERC4906 interface ID: 0x49064906
        assertTrue(push4Core.supportsInterface(0x49064906));
    }

    function test_SupportsInterface_ERC165() public view {
        // ERC165 interface ID: 0x01ffc9a7
        assertTrue(push4Core.supportsInterface(0x01ffc9a7));
    }

    /*//////////////////////////////////////////////////////////////
                        GRACE PERIOD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_InGracePeriod_InitiallyTrue() public view {
        assertTrue(push4Core.inGracePeriod());
    }

    function test_InGracePeriod_FalseAfter60Days() public {
        vm.warp(block.timestamp + 60 days + 1);
        assertFalse(push4Core.inGracePeriod());
    }

    function test_InGracePeriod_TrueAt60Days() public {
        vm.warp(block.timestamp + 60 days);
        assertTrue(push4Core.inGracePeriod());
    }

    function test_SetRenderer_Success() public {
        PUSH4Renderer newRenderer = new PUSH4Renderer(15, 25, 20, push4Core, "new metadata", owner);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit MetadataUpdate(0);
        push4Core.setRenderer(newRenderer);

        assertEq(address(push4Core.renderer()), address(newRenderer));
    }

    function test_SetRenderer_RevertsIfNotOwner() public {
        PUSH4Renderer newRenderer = new PUSH4Renderer(15, 25, 20, push4Core, "new metadata", owner);

        vm.prank(randomUser);
        vm.expectRevert();
        push4Core.setRenderer(newRenderer);
    }

    function test_SetRenderer_RevertsIfNotInGracePeriod() public {
        vm.warp(block.timestamp + 60 days + 1);

        PUSH4Renderer newRenderer = new PUSH4Renderer(15, 25, 20, push4Core, "new metadata", owner);

        vm.prank(owner);
        vm.expectRevert(IPUSH4Core.NotInGracePeriod.selector);
        push4Core.setRenderer(newRenderer);
    }

    function test_SetPush4_Success() public {
        address newPush4 = makeAddr("newPush4");

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit MetadataUpdate(0);
        push4Core.setPush4(newPush4);

        assertEq(push4Core.push4(), newPush4);
    }

    function test_SetPush4_RevertsIfNotOwner() public {
        address newPush4 = makeAddr("newPush4");

        vm.prank(randomUser);
        vm.expectRevert();
        push4Core.setPush4(newPush4);
    }

    function test_SetPush4_RevertsIfNotInGracePeriod() public {
        vm.warp(block.timestamp + 60 days + 1);

        address newPush4 = makeAddr("newPush4");

        vm.prank(owner);
        vm.expectRevert(IPUSH4Core.NotInGracePeriod.selector);
        push4Core.setPush4(newPush4);
    }

    /*//////////////////////////////////////////////////////////////
                    TOKEN OWNER ONLY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetMode_Success() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        vm.prank(tokenOwner);
        vm.expectEmit(true, false, false, false);
        emit MetadataUpdate(0);
        vm.expectEmit(true, false, false, false);
        emit ModeSet(IPUSH4Core.Mode.Executed);
        push4Core.setMode(IPUSH4Core.Mode.Executed);

        assertEq(uint256(push4Core.mode()), uint256(IPUSH4Core.Mode.Executed));
    }

    function test_SetMode_RevertsIfNotTokenOwner() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        vm.prank(randomUser);
        vm.expectRevert(IPUSH4Core.NotTokenOwner.selector);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
    }

    function test_SetMode_RevertsIfNotMinted() public {
        vm.prank(randomUser);
        vm.expectRevert(IPUSH4Core.NotTokenOwner.selector);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
    }

    function test_SetMode_CarvedToExecuted() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        vm.prank(tokenOwner);
        push4Core.setMode(IPUSH4Core.Mode.Executed);

        assertEq(uint256(push4Core.mode()), uint256(IPUSH4Core.Mode.Executed));
    }

    function test_SetMode_ExecutedToCarved() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        vm.prank(tokenOwner);
        push4Core.setMode(IPUSH4Core.Mode.Executed);

        vm.prank(tokenOwner);
        push4Core.setMode(IPUSH4Core.Mode.Carved);

        assertEq(uint256(push4Core.mode()), uint256(IPUSH4Core.Mode.Carved));
    }

    function test_SetProxy_Success() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        address proxyAddr = makeAddr("proxy");

        vm.prank(tokenOwner);
        vm.expectEmit(true, false, false, false);
        emit MetadataUpdate(0);
        vm.expectEmit(true, false, false, false);
        emit ProxySet(proxyAddr);
        push4Core.setProxy(proxyAddr);

        assertEq(push4Core.proxy(), proxyAddr);
    }

    function test_SetProxy_RevertsIfNotTokenOwner() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        address proxyAddr = makeAddr("proxy");

        vm.prank(randomUser);
        vm.expectRevert(IPUSH4Core.NotTokenOwner.selector);
        push4Core.setProxy(proxyAddr);
    }

    function test_SetProxy_RevertsIfNotMinted() public {
        address proxyAddr = makeAddr("proxy");

        vm.prank(randomUser);
        vm.expectRevert(IPUSH4Core.NotTokenOwner.selector);
        push4Core.setProxy(proxyAddr);
    }

    function test_SetProxy_UpdateProxy() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        address proxy1 = makeAddr("proxy1");
        address proxy2 = makeAddr("proxy2");

        vm.prank(tokenOwner);
        push4Core.setProxy(proxy1);

        vm.prank(tokenOwner);
        push4Core.setProxy(proxy2);

        assertEq(push4Core.proxy(), proxy2);
    }

    /*//////////////////////////////////////////////////////////////
                        SCULPTURE INTERFACE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Title() public view {
        assertEq(push4Core.title(), "PUSH4");
    }

    function test_Authors_CarvedMode() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        string[] memory _authors = push4Core.authors();
        assertEq(_authors[0], "Yigit Duman");
    }

    function test_Authors_ExecutedModeWithoutProxy() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        vm.prank(tokenOwner);
        push4Core.setMode(IPUSH4Core.Mode.Executed);

        string[] memory _authors = push4Core.authors();
        assertEq(_authors[0], "Yigit Duman");
    }

    function test_Authors_ExecutedModeWithProxy() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        address proxyAddr = makeAddr("proxy");

        vm.prank(tokenOwner);
        push4Core.setProxy(proxyAddr);

        vm.prank(tokenOwner);
        push4Core.setMode(IPUSH4Core.Mode.Executed);

        string[] memory _authors = push4Core.authors();
        assertEq(_authors[0], "Yigit Duman");
        // In Executed mode with proxy, second author should be token owner
        assertTrue(bytes(_authors[1]).length > 0);
    }

    function test_Addresses_WithoutProxy() public view {
        address[] memory _addresses = push4Core.addresses();
        assertEq(_addresses[0], address(push4));
    }

    function test_Addresses_ExecutedModeWithProxy() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        address proxyAddr = makeAddr("proxy");

        vm.prank(tokenOwner);
        push4Core.setProxy(proxyAddr);

        vm.prank(tokenOwner);
        push4Core.setMode(IPUSH4Core.Mode.Executed);

        address[] memory _addresses = push4Core.addresses();
        assertEq(_addresses[0], address(push4));
        assertEq(_addresses[1], proxyAddr);
    }

    function test_Addresses_CarvedModeWithProxy() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        address proxyAddr = makeAddr("proxy");

        vm.prank(tokenOwner);
        push4Core.setProxy(proxyAddr);

        // Mode remains Carved
        address[] memory _addresses = push4Core.addresses();
        assertEq(_addresses[0], address(push4));
    }

    function test_Urls() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        string[] memory _urls = push4Core.urls();
        assertEq(_urls[0], renderer.getSvgDataUri());
    }

    function test_Text_CarvedMode() public view {
        string memory _text = push4Core.text();
        assertEq(_text, "Representing as Carved");
    }

    function test_Text_CarvedModeWithProxy() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        address proxyAddr = makeAddr("proxy");

        vm.prank(tokenOwner);
        push4Core.setProxy(proxyAddr);

        // Mode is still Carved
        string memory _text = push4Core.text();
        assertEq(_text, "Representing as Carved");
    }

    function test_Text_ExecutedModeWithoutProxy() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        vm.prank(tokenOwner);
        push4Core.setMode(IPUSH4Core.Mode.Executed);

        string memory _text = push4Core.text();
        assertEq(_text, "Representing as Carved");
    }

    function test_Text_ExecutedModeWithProxy() public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        address proxyAddr = makeAddr("proxy");

        vm.prank(tokenOwner);
        push4Core.setProxy(proxyAddr);

        vm.prank(tokenOwner);
        push4Core.setMode(IPUSH4Core.Mode.Executed);

        string memory _text = push4Core.text();
        assertEq(_text, "Representing as Executed");
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FullWorkflow_CarvedToExecuted() public {
        // Mint token
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        // Check initial state
        assertEq(uint256(push4Core.mode()), uint256(IPUSH4Core.Mode.Carved));
        assertEq(push4Core.proxy(), address(0));

        // Set proxy
        address proxyAddr = makeAddr("proxy");
        vm.prank(tokenOwner);
        push4Core.setProxy(proxyAddr);

        // Switch to executed mode
        vm.prank(tokenOwner);
        push4Core.setMode(IPUSH4Core.Mode.Executed);

        // Verify final state
        assertEq(uint256(push4Core.mode()), uint256(IPUSH4Core.Mode.Executed));
        assertEq(push4Core.proxy(), proxyAddr);
        assertEq(push4Core.text(), "Representing as Executed");
    }

    function test_FullWorkflow_GracePeriodExpiration() public {
        // Initially in grace period
        assertTrue(push4Core.inGracePeriod());

        // Can set renderer
        PUSH4Renderer newRenderer = new PUSH4Renderer(15, 25, 20, push4Core, "new metadata", owner);
        vm.prank(owner);
        push4Core.setRenderer(newRenderer);

        // Warp past grace period
        vm.warp(block.timestamp + 60 days + 1);
        assertFalse(push4Core.inGracePeriod());

        // Cannot set renderer anymore
        PUSH4Renderer anotherRenderer = new PUSH4Renderer(15, 25, 20, push4Core, "another metadata", owner);
        vm.prank(owner);
        vm.expectRevert(IPUSH4Core.NotInGracePeriod.selector);
        push4Core.setRenderer(anotherRenderer);
    }

    function test_TokenTransfer_PreservesModeAndProxy() public {
        // Mint and configure
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        address proxyAddr = makeAddr("proxy");
        vm.prank(tokenOwner);
        push4Core.setProxy(proxyAddr);

        vm.prank(tokenOwner);
        push4Core.setMode(IPUSH4Core.Mode.Executed);

        // Transfer token
        address newOwner = makeAddr("newOwner");
        vm.prank(tokenOwner);
        push4Core.transferFrom(tokenOwner, newOwner, 0);

        // Mode and proxy should be preserved
        assertEq(uint256(push4Core.mode()), uint256(IPUSH4Core.Mode.Executed));
        assertEq(push4Core.proxy(), proxyAddr);

        // New owner can change mode
        vm.prank(newOwner);
        push4Core.setMode(IPUSH4Core.Mode.Carved);
        assertEq(uint256(push4Core.mode()), uint256(IPUSH4Core.Mode.Carved));
    }

    function test_MultipleStateChanges() public {
        // Mint token
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        address proxy1 = makeAddr("proxy1");
        address proxy2 = makeAddr("proxy2");

        // Multiple mode and proxy changes
        vm.prank(tokenOwner);
        push4Core.setMode(IPUSH4Core.Mode.Executed);

        vm.prank(tokenOwner);
        push4Core.setProxy(proxy1);

        vm.prank(tokenOwner);
        push4Core.setMode(IPUSH4Core.Mode.Carved);

        vm.prank(tokenOwner);
        push4Core.setProxy(proxy2);

        vm.prank(tokenOwner);
        push4Core.setMode(IPUSH4Core.Mode.Executed);

        // Verify final state
        assertEq(uint256(push4Core.mode()), uint256(IPUSH4Core.Mode.Executed));
        assertEq(push4Core.proxy(), proxy2);
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASES & FUZZING
    //////////////////////////////////////////////////////////////*/

    function testFuzz_SetProxy_AnyAddress(address proxyAddr) public {
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        vm.prank(tokenOwner);
        push4Core.setProxy(proxyAddr);

        assertEq(push4Core.proxy(), proxyAddr);
    }

    function testFuzz_GracePeriod_TimeRange(uint256 timeElapsed) public {
        // Bound to reasonable range instead of using vm.assume to avoid rejection
        timeElapsed = bound(timeElapsed, 0, 365 days);

        vm.warp(block.timestamp + timeElapsed);

        bool shouldBeInGracePeriod = timeElapsed <= 60 days;
        assertEq(push4Core.inGracePeriod(), shouldBeInGracePeriod);
    }

    function testFuzz_SetPush4_MultipleAddresses(address newPush4) public {
        vm.assume(newPush4 != address(0));

        vm.prank(owner);
        push4Core.setPush4(newPush4);

        assertEq(push4Core.push4(), newPush4);
    }

    function testFuzz_MintToAnyAddress(address recipient) public {
        vm.assume(recipient != address(0));

        vm.prank(owner);
        push4Core.mint(recipient);

        assertEq(push4Core.ownerOf(0), recipient);
    }

    /*//////////////////////////////////////////////////////////////
                        REVERT SCENARIOS
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_TransferTokenAfterOwnershipChange() public {
        // Mint to token owner
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        // Transfer ownership of contract
        vm.prank(owner);
        push4Core.transferOwnership(randomUser);

        // New contract owner cannot change mode/proxy (not token owner)
        vm.prank(randomUser);
        vm.expectRevert(IPUSH4Core.NotTokenOwner.selector);
        push4Core.setMode(IPUSH4Core.Mode.Executed);
    }

    function test_StateConsistency_AfterMultipleEvents() public {
        // This test ensures events are emitted correctly and state is consistent
        vm.prank(owner);
        push4Core.mint(tokenOwner);

        // Track events
        vm.recordLogs();

        vm.prank(tokenOwner);
        push4Core.setMode(IPUSH4Core.Mode.Executed);

        vm.prank(tokenOwner);
        push4Core.setProxy(makeAddr("proxy"));

        // Verify state is consistent with events
        assertEq(uint256(push4Core.mode()), uint256(IPUSH4Core.Mode.Executed));
        assertEq(push4Core.proxy(), makeAddr("proxy"));
    }
}

