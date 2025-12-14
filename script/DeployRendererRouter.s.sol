// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { BaseScript } from "./Base.s.sol";
import { PUSH4RendererRouter } from "../src/PUSH4RendererRouter.sol";
import { IPUSH4Renderer } from "../src/interface/IPUSH4Renderer.sol";
import { PUSH4Core } from "../src/PUSH4Core.sol";
import { ICreateX } from "./interfaces/ICreateX.sol";

contract DeployRendererRouter is BaseScript {
    ICreateX public constant CREATEX_FACTORY = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    function run() public broadcast returns (PUSH4RendererRouter router) {
        IPUSH4Renderer renderer = IPUSH4Renderer(0x00000063Bbe182593913e09b8A481D58ADc31042);
        PUSH4Core push4Core = PUSH4Core(0x00000063266aAAeDD489e4956153855626E44061);

        // Deploy PUSH4RendererRouter via CREATE2
        bytes32 routerSalt = bytes32(0x28996f7dece7e058ebfc56dfa9371825fbfa515a009de7d4b4b6bae70002c422); // 0x000000636fac63f4f4c12c8674fb5d11f9a08753
        bytes memory routerCreationCode =
            abi.encodePacked(type(PUSH4RendererRouter).creationCode, abi.encode(renderer, broadcaster));
        router = PUSH4RendererRouter(CREATEX_FACTORY.deployCreate2(routerSalt, routerCreationCode));

        push4Core.setRenderer(router);
    }
}
