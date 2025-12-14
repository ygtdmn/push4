// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { BaseScript } from "./Base.s.sol";
import { PUSH4Renderer } from "../src/PUSH4Renderer.sol";

contract UpdateMetadata is BaseScript {
    function run() public broadcast {
        string memory metadata =
            unicode"\"name\": \"PUSH4\",\"description\": \"PUSH4 encodes Barnett Newman's Onement I (1948) into the function selectors of a Solidity smart contract. Each of the 375 pixels in the image exists as a function on the Ethereum blockchain, mined using a custom GPU tool that brute-forces function names until their 4-byte selector hashes match the exact color data required.\\n\\nThe title references `PUSH4`, the EVM opcode that pushes a 4-byte function selector onto the stack, the fundamental mechanism by which smart contracts route calls to their functions.\"";
        PUSH4Renderer renderer = PUSH4Renderer(0x00000063Bbe182593913e09b8A481D58ADc31042);
        renderer.setMetadata(metadata);
    }
}
