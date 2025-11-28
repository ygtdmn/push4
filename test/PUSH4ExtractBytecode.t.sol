// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { PUSH4 } from "../src/PUSH4.sol";
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { PUSH4RendererMock } from "./mocks/PUSH4RendererMock.sol";
import { IPUSH4Core } from "../src/interface/IPUSH4Core.sol";

contract PUSH4ExtractBytecode is Test {
    function test_extractSelectorsFromBytecode() public {
        PUSH4RendererMock renderer = new PUSH4RendererMock(15, 25, 20, IPUSH4Core(address(0x0)), "", address(this));
        PUSH4 push4 = new PUSH4();

        bytes4[] memory selectors = renderer.extractSelectorsFromBytecode(address(push4), 375, true);
        for (uint256 i = 0; i < selectors.length; i++) {
            console2.logBytes4(selectors[i]);
        }
    }
}
