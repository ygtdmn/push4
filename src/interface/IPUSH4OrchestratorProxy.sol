// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { IPUSH4Proxy } from "./IPUSH4Proxy.sol";

interface IPUSH4OrchestratorProxy is IPUSH4Proxy {
    function owner() external view returns (address);
    function isCreator(address account) external view returns (bool);
}
