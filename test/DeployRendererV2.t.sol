// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { PUSH4RendererV2 } from "../src/PUSH4RendererV2.sol";
import { PUSH4RendererRouter } from "../src/PUSH4RendererRouter.sol";
import { IPUSH4Core } from "../src/interface/IPUSH4Core.sol";
import { PUSH4Core } from "../src/PUSH4Core.sol";
import { IMURIProtocol } from "../src/interface/IMURIProtocol.sol";
import { PUSH4MURIOperator } from "../src/PUSH4MURIOperator.sol";
import { PUSH4OrchestratorProxy } from "../src/PUSH4OrchestratorProxy.sol";
import { console2 } from "forge-std/console2.sol";
import { PUSH4OriginalProxy } from "../src/PUSH4OriginalProxy.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title DeployRendererV2
/// @notice Deploys PUSH4RendererV2 with SSTORE2-based HTML template
contract DeployRendererV2Test is Test {
    // Deployed contract addresses (mainnet/sepolia)
    address constant PUSH4_CORE_ADDRESS = 0x00000063266aAAeDD489e4956153855626E44061;
    address constant RENDERER_ROUTER_ADDRESS = 0x000000636fAc63F4f4C12c8674Fb5D11f9A08753;
    address constant MURI_PROTOCOL = 0x0000000000C2A0B63ab4aA971B08B905E5875b01;

    // Configuration
    uint256 constant WIDTH = 15;
    uint256 constant HEIGHT = 25;
    uint256 constant PIXEL_SIZE = 20;
    uint256 constant BLOCK_INTERVAL = 5;

    string constant METADATA =
        unicode"\"name\": \"PUSH4\",\"description\": \"PUSH4 encodes Barnett Newman's Onement I (1948) into the function selectors of a Solidity smart contract. Each of the 375 pixels in the image exists as a function on the Ethereum blockchain, mined using a custom GPU tool that brute-forces function names until their 4-byte selector hashes match the exact color data required.\\n\\nThe title references `PUSH4`, the EVM opcode that pushes a 4-byte function selector onto the stack, the fundamental mechanism by which smart contracts route calls to their functions.\"";

    function test_TestRendererV2() public returns (PUSH4RendererV2 rendererV2) {
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY is not set");
        }

        // Otherwise, run the test against the mainnet fork.
        vm.createSelectFork({ urlOrAlias: "mainnet" });
        address collector = 0x478087E12DB15302a364C64CDB79F14Ae6C5C9b7;
        address broadcaster = 0x28996f7DECe7E058EBfC56dFa9371825fBfa515A;
        vm.startPrank(broadcaster);
        PUSH4Core push4Core = PUSH4Core(PUSH4_CORE_ADDRESS);

        // Load HTML template from file
        string memory htmlTemplate = vm.readFile("script/assets/renderer-v2.html");

        string[] memory htmlTemplateChunks = new string[](1);
        htmlTemplateChunks[0] = htmlTemplate;

        // Deploy RendererV2
        rendererV2 = new PUSH4RendererV2(
            WIDTH, HEIGHT, PIXEL_SIZE, IPUSH4Core(address(push4Core)), METADATA, BLOCK_INTERVAL, broadcaster
        );

        // Update the renderer router to point to the new renderer
        PUSH4RendererRouter router = PUSH4RendererRouter(RENDERER_ROUTER_ADDRESS);
        router.setRenderer(rendererV2);

        rendererV2.setMURIProtocol(MURI_PROTOCOL);
        PUSH4OrchestratorProxy orchestrator =
            new PUSH4OrchestratorProxy(broadcaster, rendererV2, IERC721(address(push4Core)));
        orchestrator.registerProxy(new PUSH4OriginalProxy());
        IMURIProtocol muriProtocol = IMURIProtocol(MURI_PROTOCOL);
        PUSH4MURIOperator muriOperator = new PUSH4MURIOperator(orchestrator, rendererV2, muriProtocol, broadcaster);
        muriProtocol.registerContract(address(push4Core), address(muriOperator));
        // CORS-friendly RPC endpoints that work from data: URIs (null origin)
        string[] memory artistUris = new string[](1);
        artistUris[0] = "http://127.0.0.1:8545";

        muriOperator.initializeTokenData(
            address(push4Core),
            0,
            IMURIProtocol.InitConfig({
                metadata: METADATA,
                displayMode: IMURIProtocol.DisplayMode.HTML,
                artwork: IMURIProtocol.Artwork({
                    artistUris: artistUris,
                    collectorUris: new string[](0),
                    selectedArtistUriIndex: 0,
                    mimeType: "text/html",
                    fileHash: "irrelevant",
                    isAnimationUri: false
                }),
                // Artist permissions (bits 0-6): update thumb, meta, choose uris, add/remove, choose thumb, update
                // mode, update template Collector permissions: choose uris (bit 7), add/remove (bit 8)
                permissions: IMURIProtocol.Permissions({
                    flags: // ARTIST_UPDATE_THUMB
                    (1 << 0) | (1 << 1) // ARTIST_UPDATE_META
                        | (1 << 2) // ARTIST_CHOOSE_URIS
                        | (1 << 3) // ARTIST_ADD_REMOVE
                        | (1 << 4) // ARTIST_CHOOSE_THUMB
                        | (1 << 5) // ARTIST_UPDATE_MODE
                        | (1 << 6) // ARTIST_UPDATE_TEMPLATE
                        | (1 << 7) // COLLECTOR_CHOOSE_URIS
                        | (1 << 8) // COLLECTOR_ADD_REMOVE
                }),
                thumbnail: IMURIProtocol.Thumbnail({
                    kind: IMURIProtocol.ThumbnailKind.OFF_CHAIN,
                    onChain: IMURIProtocol.OnChainThumbnail({
                        chunks: new address[](0), mimeType: "image/png", zipped: false
                    }),
                    offChain: IMURIProtocol.OffChainThumbnail({ uris: new string[](1), selectedUriIndex: 0 })
                }),
                htmlTemplate: IMURIProtocol.HtmlTemplate({ chunks: new address[](0), zipped: false })
            }),
            new bytes[](0),
            htmlTemplateChunks
        );
        vm.stopPrank();
        vm.startPrank(collector);
        push4Core.setProxy(address(orchestrator));
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        vm.stopPrank();
        console2.log("Token URI: ", push4Core.tokenURI(0));
        // console2.log(rendererV2.getAnimationUrl());
    }
}
