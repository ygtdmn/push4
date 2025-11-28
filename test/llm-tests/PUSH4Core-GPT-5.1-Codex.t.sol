// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";
import { PUSH4Core } from "../../src/PUSH4Core.sol";
import { IPUSH4Core } from "../../src/interface/IPUSH4Core.sol";
import { IPUSH4Renderer } from "../../src/interface/IPUSH4Renderer.sol";

contract PUSH4CoreGPT51CodexTest is Test {
    event MetadataUpdate(uint256 _tokenId);
    event ModeSet(IPUSH4Core.Mode _mode);
    event ProxySet(address _proxy);

    uint256 internal constant START_TIME = 1_900_000_000;

    PUSH4Core internal core;
    RendererStub internal renderer;

    address internal owner = makeAddr("owner");
    address internal push4 = makeAddr("push4");
    address internal collector = makeAddr("collector");
    address internal attacker = makeAddr("attacker");
    address internal proxy = makeAddr("proxy");
    address internal replacementPush4 = makeAddr("replacementPush4");

    function setUp() public {
        vm.warp(START_TIME);
        core = new PUSH4Core(push4, owner);
        renderer = new RendererStub(core);
    }

    function testConstructorInitializesState() public view {
        assertEq(core.push4(), push4);
        assertEq(core.owner(), owner);
        assertEq(core.deploymentTimestamp(), START_TIME);
        assertTrue(core.inGracePeriod());
        assertEq(uint256(core.mode()), uint256(IPUSH4Core.Mode.Carved));
        assertEq(core.proxy(), address(0));
        assertEq(core.TOKEN_ID(), 0);
        assertEq(core.totalSupply(), 0);
        assertEq(core.name(), "PUSH4");
        assertEq(core.symbol(), "PUSH4");
        assertEq(core.title(), "PUSH4");
    }

    function testMintRestrictedAndSingleSupply() public {
        vm.prank(attacker);
        vm.expectRevert();
        core.mint(collector);

        vm.prank(owner);
        core.mint(collector);

        assertEq(core.ownerOf(core.TOKEN_ID()), collector);
        assertEq(core.totalSupply(), 1);
        assertEq(core.balanceOf(collector), 1);

        vm.prank(owner);
        vm.expectRevert(IPUSH4Core.AlreadyMinted.selector);
        core.mint(collector);
    }

    function testTokenURIRequiresMint() public {
        uint256 tokenId = core.TOKEN_ID();
        vm.expectRevert(IPUSH4Core.NotMinted.selector);
        core.tokenURI(tokenId);
    }

    function testTokenURIReturnsRendererValueOnceMinted() public {
        vm.prank(owner);
        core.setRenderer(renderer);

        _mintToCollector();

        assertEq(core.tokenURI(core.TOKEN_ID()), renderer.getMetadataDataUri());
    }

    function testSetRendererOnlyOwnerDuringGracePeriod() public {
        vm.prank(attacker);
        vm.expectRevert();
        core.setRenderer(renderer);

        vm.expectEmit();
        emit MetadataUpdate(core.TOKEN_ID());
        vm.prank(owner);
        core.setRenderer(renderer);
        assertEq(address(core.renderer()), address(renderer));

        vm.warp(START_TIME + 60 days + 1);
        RendererStub newRenderer = new RendererStub(core);
        vm.prank(owner);
        vm.expectRevert(IPUSH4Core.NotInGracePeriod.selector);
        core.setRenderer(newRenderer);
    }

    function testSetPush4OnlyOwnerDuringGracePeriod() public {
        vm.prank(attacker);
        vm.expectRevert();
        core.setPush4(replacementPush4);

        vm.expectEmit();
        emit MetadataUpdate(core.TOKEN_ID());
        vm.prank(owner);
        core.setPush4(replacementPush4);
        assertEq(core.push4(), replacementPush4);

        vm.warp(START_TIME + 60 days + 1);
        address nextPush4 = makeAddr("nextPush4");
        vm.prank(owner);
        vm.expectRevert(IPUSH4Core.NotInGracePeriod.selector);
        core.setPush4(nextPush4);
    }

    function testSetModeOnlyTokenOwnerAndEmits() public {
        _mintToCollector();

        vm.prank(owner);
        vm.expectRevert(IPUSH4Core.NotTokenOwner.selector);
        core.setMode(IPUSH4Core.Mode.Executed);

        vm.expectEmit();
        emit MetadataUpdate(core.TOKEN_ID());
        vm.expectEmit();
        emit ModeSet(IPUSH4Core.Mode.Executed);
        vm.prank(collector);
        core.setMode(IPUSH4Core.Mode.Executed);

        assertEq(uint256(core.mode()), uint256(IPUSH4Core.Mode.Executed));
    }

    function testSetProxyOnlyTokenOwnerAndEmits() public {
        _mintToCollector();

        vm.prank(owner);
        vm.expectRevert(IPUSH4Core.NotTokenOwner.selector);
        core.setProxy(proxy);

        vm.expectEmit();
        emit MetadataUpdate(core.TOKEN_ID());
        vm.expectEmit();
        emit ProxySet(proxy);
        vm.prank(collector);
        core.setProxy(proxy);

        assertEq(core.proxy(), proxy);
    }

    function testTextReflectsModeAndProxyState() public {
        assertEq(core.text(), "Representing as Carved");

        vm.prank(owner);
        core.mint(collector);
        vm.prank(collector);
        core.setProxy(proxy);

        assertEq(core.text(), "Representing as Carved");

        vm.prank(collector);
        core.setMode(IPUSH4Core.Mode.Executed);

        assertEq(core.text(), "Representing as Executed");
    }

    function testSupportsERC4906Interface() public view {
        assertTrue(core.supportsInterface(0x49064906));
    }

    function testGracePeriodExpiresAfterSixtyDays() public {
        assertTrue(core.inGracePeriod());
        vm.warp(START_TIME + 60 days + 1);
        assertFalse(core.inGracePeriod());
    }

    function _mintToCollector() internal {
        vm.prank(owner);
        core.mint(collector);
    }
}

contract RendererStub is IPUSH4Renderer {
    IPUSH4Core private immutable _core;
    string private constant METADATA_URI = "data:application/json;base64,deadbeef";
    string private constant SVG_URI = "data:image/svg+xml;base64,cafebabe";

    constructor(IPUSH4Core core_) {
        _core = core_;
    }

    function width() external pure returns (uint256) {
        return 1;
    }

    function height() external pure returns (uint256) {
        return 1;
    }

    function pixelSize() external pure returns (uint256) {
        return 1;
    }

    function push4Core() external view returns (IPUSH4Core) {
        return _core;
    }

    function getPixels(IPUSH4Core.Mode) external pure returns (bytes4[] memory pixels) {
        pixels = new bytes4[](0);
    }

    function getSvg() external pure returns (string memory) {
        return SVG_URI;
    }

    function getSvgDataUri() external pure returns (string memory) {
        return SVG_URI;
    }

    function getMetadata() external pure returns (string memory) {
        return METADATA_URI;
    }

    function getMetadataDataUri() external pure returns (string memory) {
        return METADATA_URI;
    }

    function getKnownFalseSelectors() external pure returns (bytes4[11] memory selectors) {
        return selectors;
    }

    function isKnownFalseSelector(bytes4) external pure returns (bool) {
        return false;
    }
}
