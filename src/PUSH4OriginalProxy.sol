// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IPUSH4Proxy } from "./interface/IPUSH4Proxy.sol";
import { IPUSH4RendererV2 } from "./interface/IPUSH4RendererV2.sol";
import { IPUSH4OrchestratorProxy } from "./interface/IPUSH4OrchestratorProxy.sol";

/**
 * @title PUSH4OriginalProxy
 * @author Yigit Duman
 */
contract PUSH4OriginalProxy is IPUSH4Proxy {
    function execute(bytes4 selector) external pure override returns (bytes4) {
        return selector;
    }

    function title() external pure override returns (string memory) {
        return "PUSH4";
    }

    function description() external pure override returns (string memory) {
        return "PUSH4 Original Proxy";
    }

    function creator() external pure override returns (Creator memory) {
        return Creator({ name: "Yigit Duman", wallet: address(0x28996f7DECe7E058EBfC56dFa9371825fBfa515A) });
    }
}
