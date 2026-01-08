// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { BaseScript } from "./Base.s.sol";
import { IMURIProtocol } from "../src/interface/IMURIProtocol.sol";
import { console2 } from "forge-std/console2.sol";
import { PUSH4Core } from "../src/PUSH4Core.sol";

/// @title UpdateHtmlTemplate
/// @notice Updates the HTML template for PUSH4 in MURI Protocol
contract UpdateHtmlTemplate is BaseScript {
    // Contract addresses
    address constant MURI_PROTOCOL = 0x0000000000C2A0B63ab4aA971B08B905E5875b01;
    address constant PUSH4_CORE = 0x00000063266aAAeDD489e4956153855626E44061;
    uint256 constant TOKEN_ID = 0;

    function run() public broadcast {
        IMURIProtocol muriProtocol = IMURIProtocol(MURI_PROTOCOL);

        // Load HTML template from file
        string memory htmlTemplate = vm.readFile("script/assets/renderer-v2.html");

        string[] memory templateParts = new string[](1);
        templateParts[0] = htmlTemplate;

        // Update the HTML template (not zipped)
        muriProtocol.updateHtmlTemplate(PUSH4_CORE, TOKEN_ID, templateParts, false);

        console2.log("HTML template updated for PUSH4 token", TOKEN_ID);
        console2.log("Template length:", bytes(htmlTemplate).length);
        console2.log("Token URI:", PUSH4Core(PUSH4_CORE).tokenURI(TOKEN_ID));
    }
}

