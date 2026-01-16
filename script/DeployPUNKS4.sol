// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { BaseScript } from "./Base.s.sol";
import { PUNKS4 } from "../src/PUNKS4.sol";
import { PUSH4ProxyFactory } from "../src/PUSH4ProxyFactory.sol";
import { IPUSH4Proxy } from "../src/interface/IPUSH4Proxy.sol";

contract DeployPUNKS4 is BaseScript {
    // PUSH4ProxyFactory on mainnet
    PUSH4ProxyFactory constant FACTORY = PUSH4ProxyFactory(0x996815bC3A8eB22aB254F2709B414b39A51e729e);

    function run() public broadcast returns (PUNKS4 punks4) {
        // Deploy PUNKS4
        punks4 = new PUNKS4();

        // Register with PUSH4ProxyFactory
        FACTORY.register(IPUSH4Proxy(address(punks4)));
    }
}
