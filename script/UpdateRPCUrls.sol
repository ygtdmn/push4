// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { BaseScript } from "./Base.s.sol";
import { PUSH4RendererV2 } from "../src/PUSH4RendererV2.sol";
import { PUSH4RendererRouter } from "../src/PUSH4RendererRouter.sol";
import { IPUSH4Core } from "../src/interface/IPUSH4Core.sol";
import { PUSH4Core } from "../src/PUSH4Core.sol";
import { IMURIProtocol } from "../src/interface/IMURIProtocol.sol";
import { PUSH4MURIOperator } from "../src/PUSH4MURIOperator.sol";
import { PUSH4OrchestratorProxy } from "../src/PUSH4OrchestratorProxy.sol";
import { console2 } from "forge-std/console2.sol";
import { PUSH4OriginalProxy } from "../src/PUSH4OriginalProxy.sol";
import { PUSH4ProxyFactory } from "../src/PUSH4ProxyFactory.sol";
import { IPUSH4Proxy } from "../src/interface/IPUSH4Proxy.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract UpdateRPCUrls is BaseScript {
    // Deployed contract addresses (mainnet/sepolia)
    address constant PUSH4_CORE_ADDRESS = 0x00000063266aAAeDD489e4956153855626E44061;
    address constant RENDERER_ROUTER_ADDRESS = 0x000000636fAc63F4f4C12c8674Fb5D11f9A08753;
    address constant MURI_PROTOCOL = 0x0000000000C2A0B63ab4aA971B08B905E5875b01;

    function run() public broadcast {
        IMURIProtocol muriProtocol = IMURIProtocol(MURI_PROTOCOL);
        uint256[] memory indices = new uint256[](4);
        indices[0] = 3;
        indices[1] = 2;
        indices[2] = 1;
        indices[3] = 0;
        muriProtocol.removeArtworkUris(PUSH4_CORE_ADDRESS, 0, indices);
        string[] memory uris = new string[](6);
        uris[0] = "https://rpc.mevblocker.io";
        uris[1] = "https://rpc.flashbots.net";
        uris[2] = "https://ethereum.public.blockpi.network/v1/rpc/public";
        uris[3] = "https://eth.drpc.org";
        uris[4] = "https://0xrpc.io/eth";
        uris[5] = "https://rpc.fullsend.to";
        muriProtocol.addArtworkUris(PUSH4_CORE_ADDRESS, 0, uris);
    }
}
