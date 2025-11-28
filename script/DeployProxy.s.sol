// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { BaseScript } from "./Base.s.sol";
import { PUSH4 } from "../src/PUSH4.sol";
import { PUSH4Core, IPUSH4Core } from "../src/PUSH4Core.sol";
import { PUSH4Renderer } from "../src/PUSH4Renderer.sol";
import { ICreateX } from "./interfaces/ICreateX.sol";
import { PUSH4ProxyTemplate } from "../src/PUSH4ProxyTemplate.sol";

contract DeployProxy is BaseScript {
    function run() public broadcast returns (PUSH4ProxyTemplate proxy) {
        PUSH4 push4 = PUSH4(0x000000630bf663df3ff850DD34a28Fb7D4d52170);
        PUSH4Core push4Core = PUSH4Core(0x00000063266aAAeDD489e4956153855626E44061);
        proxy = new PUSH4ProxyTemplate(address(push4), address(push4Core));
        push4Core.setProxy(address(proxy));
        push4Core.setMode(IPUSH4Core.Mode.Executed);
    }
}
