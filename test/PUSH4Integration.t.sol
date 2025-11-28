// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { PUSH4Core, IPUSH4Core } from "../src/PUSH4Core.sol";
import { PUSH4 } from "../src/PUSH4.sol";
import { PUSH4Renderer } from "../src/PUSH4Renderer.sol";
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { PUSH4ProxyTemplate } from "../src/PUSH4ProxyTemplate.sol";
import { PUSH4TestBase } from "./PUSH4TestBase.sol";

contract PUSH4Integration is PUSH4TestBase {
    string constant METADATA =
        unicode"\"name\": \"PUSH4\",\"description\": \"A heavily compressed and dithered down version of Barnett Newman's Onement I, encoded in 375 smart contract function selectors.\"";

    function setUp() public {
        _fullSetup(address(this), 15, 25, 20, METADATA);
        console2.log(address(push4Core));
    }

    function test_tokenURI() public {
        push4Core.mint(address(this));
        string memory tokenURI = push4Core.tokenURI(0);
        console2.log(tokenURI);
    }

    function test_Proxy() public {
        push4Core.mint(address(this));
        push4Core.setProxy(address(proxyTemplate));
        push4Core.setMode(IPUSH4Core.Mode.Executed);
        string memory dataUri = renderer.getSvgDataUri();
        console2.log(dataUri);
    }
}
