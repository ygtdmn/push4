// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { BaseScript } from "./Base.s.sol";
import { PUSH4 } from "../src/PUSH4.sol";
import { PUSH4Core } from "../src/PUSH4Core.sol";
import { PUSH4Renderer } from "../src/PUSH4Renderer.sol";
import { ICreateX } from "./interfaces/ICreateX.sol";

contract Deploy is BaseScript {
    ICreateX public constant CREATEX_FACTORY = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    function run() public broadcast returns (PUSH4Renderer renderer, PUSH4Core push4Core, PUSH4 push4) {
        // Generate deterministic salts for each contract
        bytes32 push4Salt = 0x28996f7dece7e058ebfc56dfa9371825fbfa515a0076a5f812acc20500b6f2d2; // 0x000000630bf663df3ff850DD34a28Fb7D4d52170
        bytes32 push4CoreSalt = 0x28996f7dece7e058ebfc56dfa9371825fbfa515a0026ff76950f16a401c442aa; // 0x00000063266aAAeDD489e4956153855626E44061
        bytes32 rendererSalt = 0x28996f7dece7e058ebfc56dfa9371825fbfa515a005cd77a16ccf53e012f5b56; // 0x00000063Bbe182593913e09b8A481D58ADc31042

        // Deploy PUSH4 via CREATE2 for deterministic deployment
        bytes memory push4CreationCode = type(PUSH4).creationCode;
        push4 = PUSH4(CREATEX_FACTORY.deployCreate2(push4Salt, push4CreationCode));

        // Deploy PUSH4Core via CREATE2 for deterministic deployment
        bytes memory push4CoreCreationCode =
            abi.encodePacked(type(PUSH4Core).creationCode, abi.encode(address(0x0), broadcaster));
        push4Core = PUSH4Core(CREATEX_FACTORY.deployCreate2(push4CoreSalt, push4CoreCreationCode));

        push4Core.setPush4(address(push4));

        // Deploy PUSH4Renderer via CREATE2 for deterministic deployment
        string memory metadata =
            unicode"\"name\": \"PUSH4\",\"description\": \"A heavily compressed and dithered down version of Barnett Newman's Onement I, encoded in 375 smart contract function selectors.\"";
        bytes memory rendererCreationCode = abi.encodePacked(
            type(PUSH4Renderer).creationCode, abi.encode(15, 25, 20, address(push4Core), metadata, broadcaster)
        );
        renderer = PUSH4Renderer(CREATEX_FACTORY.deployCreate2(rendererSalt, rendererCreationCode));

        // Set the renderer on the push4Core
        push4Core.setRenderer(renderer);
    }
}
