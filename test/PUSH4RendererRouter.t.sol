// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";
import { PUSH4RendererRouter } from "../src/PUSH4RendererRouter.sol";
import { PUSH4Renderer } from "../src/PUSH4Renderer.sol";
import { IPUSH4Renderer } from "../src/interface/IPUSH4Renderer.sol";
import { IPUSH4RendererRouter } from "../src/interface/IPUSH4RendererRouter.sol";
import { IPUSH4Core } from "../src/interface/IPUSH4Core.sol";
import { PUSH4TestBase } from "./PUSH4TestBase.sol";

contract PUSH4RendererRouterTest is PUSH4TestBase {
    PUSH4RendererRouter public router;
    PUSH4Renderer public renderer2;

    address public owner = address(this);
    address public alice = makeAddr("alice");

    uint256 constant WIDTH = 15;
    uint256 constant HEIGHT = 25;
    uint256 constant PIXEL_SIZE = 20;

    string constant METADATA = unicode"\"name\": \"PUSH4\",\"description\": \"Test metadata\"";

    event RendererSet(IPUSH4Renderer indexed newRenderer);
    event RendererLocked(IPUSH4Renderer indexed lockedRenderer);

    function setUp() public {
        _fullSetup(owner, WIDTH, HEIGHT, PIXEL_SIZE, METADATA);

        // Create the router with the renderer from _fullSetup
        router = new PUSH4RendererRouter(renderer, owner);

        // Create a second renderer for testing setRenderer
        renderer2 = new PUSH4Renderer(WIDTH + 5, HEIGHT + 5, PIXEL_SIZE + 5, push4Core, "\"name\": \"PUSH4 v2\"", owner);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsRenderer() public view {
        assertEq(address(router.renderer()), address(renderer));
    }

    function test_constructor_setsOwner() public view {
        assertEq(router.owner(), owner);
    }

    function test_constructor_isNotLocked() public view {
        assertFalse(router.isLocked());
    }

    function test_constructor_emitsRendererSet() public {
        vm.expectEmit(true, true, true, true);
        emit RendererSet(renderer);
        new PUSH4RendererRouter(renderer, owner);
    }

    function test_constructor_revertsOnZeroAddress() public {
        vm.expectRevert(IPUSH4RendererRouter.InvalidRenderer.selector);
        new PUSH4RendererRouter(IPUSH4Renderer(address(0)), owner);
    }

    /*//////////////////////////////////////////////////////////////
                              SET RENDERER
    //////////////////////////////////////////////////////////////*/

    function test_setRenderer_updatesRenderer() public {
        router.setRenderer(renderer2);
        assertEq(address(router.renderer()), address(renderer2));
    }

    function test_setRenderer_emitsRendererSet() public {
        vm.expectEmit(true, true, true, true);
        emit RendererSet(renderer2);
        router.setRenderer(renderer2);
    }

    function test_setRenderer_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        router.setRenderer(renderer2);
    }

    function test_setRenderer_revertsOnZeroAddress() public {
        vm.expectRevert(IPUSH4RendererRouter.InvalidRenderer.selector);
        router.setRenderer(IPUSH4Renderer(address(0)));
    }

    function test_setRenderer_revertsWhenLocked() public {
        router.lockRenderer();
        vm.expectRevert(IPUSH4RendererRouter.RendererIsLocked.selector);
        router.setRenderer(renderer2);
    }

    function test_setRenderer_canChangeMultipleTimes() public {
        router.setRenderer(renderer2);
        assertEq(address(router.renderer()), address(renderer2));

        router.setRenderer(renderer);
        assertEq(address(router.renderer()), address(renderer));

        router.setRenderer(renderer2);
        assertEq(address(router.renderer()), address(renderer2));
    }

    /*//////////////////////////////////////////////////////////////
                              LOCK RENDERER
    //////////////////////////////////////////////////////////////*/

    function test_lockRenderer_setsIsLocked() public {
        assertFalse(router.isLocked());
        router.lockRenderer();
        assertTrue(router.isLocked());
    }

    function test_lockRenderer_emitsRendererLocked() public {
        vm.expectEmit(true, true, true, true);
        emit RendererLocked(renderer);
        router.lockRenderer();
    }

    function test_lockRenderer_revertsWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        router.lockRenderer();
    }

    function test_lockRenderer_revertsWhenAlreadyLocked() public {
        router.lockRenderer();
        vm.expectRevert(IPUSH4RendererRouter.RendererIsLocked.selector);
        router.lockRenderer();
    }

    function test_lockRenderer_preventsSetRenderer() public {
        router.lockRenderer();
        vm.expectRevert(IPUSH4RendererRouter.RendererIsLocked.selector);
        router.setRenderer(renderer2);
    }

    function test_lockRenderer_isIrreversible() public {
        router.lockRenderer();
        assertTrue(router.isLocked());
        // There's no way to unlock - the contract has no unlock function
        // This is by design - once locked, it's permanent
    }

    /*//////////////////////////////////////////////////////////////
                         PASSTHROUGH FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_width_delegatesToRenderer() public view {
        assertEq(router.width(), renderer.width());
        assertEq(router.width(), WIDTH);
    }

    function test_height_delegatesToRenderer() public view {
        assertEq(router.height(), renderer.height());
        assertEq(router.height(), HEIGHT);
    }

    function test_pixelSize_delegatesToRenderer() public view {
        assertEq(router.pixelSize(), renderer.pixelSize());
        assertEq(router.pixelSize(), PIXEL_SIZE);
    }

    function test_push4Core_delegatesToRenderer() public view {
        assertEq(address(router.push4Core()), address(renderer.push4Core()));
        assertEq(address(router.push4Core()), address(push4Core));
    }

    function test_getPixels_delegatesToRenderer() public view {
        bytes4[] memory routerPixels = router.getPixels(IPUSH4Core.Mode.Carved);
        bytes4[] memory rendererPixels = renderer.getPixels(IPUSH4Core.Mode.Carved);

        assertEq(routerPixels.length, rendererPixels.length);
        for (uint256 i = 0; i < routerPixels.length; i++) {
            assertEq(routerPixels[i], rendererPixels[i]);
        }
    }

    function test_getSvg_delegatesToRenderer() public view {
        assertEq(router.getSvg(), renderer.getSvg());
    }

    function test_getSvgDataUri_delegatesToRenderer() public view {
        assertEq(router.getSvgDataUri(), renderer.getSvgDataUri());
    }

    function test_getMetadata_delegatesToRenderer() public view {
        assertEq(router.getMetadata(), renderer.getMetadata());
    }

    function test_getMetadataDataUri_delegatesToRenderer() public view {
        assertEq(router.getMetadataDataUri(), renderer.getMetadataDataUri());
    }

    /*//////////////////////////////////////////////////////////////
                      PASSTHROUGH AFTER RENDERER CHANGE
    //////////////////////////////////////////////////////////////*/

    function test_passthrough_updatesAfterSetRenderer() public {
        // Initial values from renderer
        assertEq(router.width(), WIDTH);
        assertEq(router.height(), HEIGHT);
        assertEq(router.pixelSize(), PIXEL_SIZE);

        // Change to renderer2
        router.setRenderer(renderer2);

        // Values should now come from renderer2
        assertEq(router.width(), WIDTH + 5);
        assertEq(router.height(), HEIGHT + 5);
        assertEq(router.pixelSize(), PIXEL_SIZE + 5);
    }

    /*//////////////////////////////////////////////////////////////
                         PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_getKnownFalseSelectors_returns11Selectors() public view {
        bytes4[11] memory selectors = router.getKnownFalseSelectors();
        assertEq(selectors.length, 11);
    }

    function test_getKnownFalseSelectors_returnsCorrectValues() public view {
        bytes4[11] memory selectors = router.getKnownFalseSelectors();
        assertEq(selectors[0], bytes4(0xec556889));
        assertEq(selectors[1], bytes4(0x6f2885b9));
        assertEq(selectors[2], bytes4(0x57509495));
        assertEq(selectors[10], bytes4(0xde510b72));
    }

    function test_isKnownFalseSelector_returnsTrueForKnown() public view {
        assertTrue(router.isKnownFalseSelector(bytes4(0xec556889)));
        assertTrue(router.isKnownFalseSelector(bytes4(0x6f2885b9)));
        assertTrue(router.isKnownFalseSelector(bytes4(0xde510b72)));
        assertTrue(router.isKnownFalseSelector(bytes4(0x00000000)));
    }

    function test_isKnownFalseSelector_returnsFalseForUnknown() public view {
        assertFalse(router.isKnownFalseSelector(bytes4(0x12345678)));
        assertFalse(router.isKnownFalseSelector(bytes4(0xdeadbeef)));
        assertFalse(router.isKnownFalseSelector(bytes4(0xffffffff)));
    }

    /*//////////////////////////////////////////////////////////////
                         INTEGRATION WITH PUSH4CORE
    //////////////////////////////////////////////////////////////*/

    function test_integration_routerWorksAsPush4CoreRenderer() public {
        // Set the router as the renderer in push4Core
        push4Core.setRenderer(router);

        // Mint a token
        push4Core.mint(owner);

        // tokenURI should work through the router
        string memory tokenURI = push4Core.tokenURI(0);
        assertGt(bytes(tokenURI).length, 0);

        // Should match what the router returns
        assertEq(tokenURI, router.getMetadataDataUri());
    }

    function test_integration_canChangeRendererAfterGracePeriod() public {
        // Set router as renderer in push4Core (within grace period)
        push4Core.setRenderer(router);

        // Warp past grace period
        vm.warp(block.timestamp + 60 days + 1);
        assertFalse(push4Core.inGracePeriod());

        // Can't change renderer in push4Core anymore
        vm.expectRevert(IPUSH4Core.NotInGracePeriod.selector);
        push4Core.setRenderer(renderer2);

        // But can still change renderer in router!
        router.setRenderer(renderer2);
        assertEq(address(router.renderer()), address(renderer2));
    }

    function test_integration_lockAfterSatisfied() public {
        // Set router as renderer in push4Core
        push4Core.setRenderer(router);

        // Warp past grace period
        vm.warp(block.timestamp + 60 days + 1);

        // Update renderer through router a few times
        router.setRenderer(renderer2);
        router.setRenderer(renderer);

        // Lock when satisfied
        router.lockRenderer();

        // Can no longer change
        vm.expectRevert(IPUSH4RendererRouter.RendererIsLocked.selector);
        router.setRenderer(renderer2);
    }
}

