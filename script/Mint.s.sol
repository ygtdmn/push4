// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { BaseScript } from "./Base.s.sol";
import { PUSH4Core } from "../src/PUSH4Core.sol";

contract Mint is BaseScript {
    function run() public broadcast {
        PUSH4Core(0x00000063266aAAeDD489e4956153855626E44061).mint(broadcaster);
    }
}
