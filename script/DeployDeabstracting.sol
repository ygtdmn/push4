// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { BaseScript } from "./Base.s.sol";
import { Deabstracting } from "../src/Deabstracting.sol";
import { PUSH4ProxyFactory } from "../src/PUSH4ProxyFactory.sol";
import { IPUSH4Proxy } from "../src/interface/IPUSH4Proxy.sol";

contract DeployDeabstracting is BaseScript {
  // PUSH4ProxyFactory on mainnet
  PUSH4ProxyFactory constant FACTORY = PUSH4ProxyFactory(0x996815bC3A8eB22aB254F2709B414b39A51e729e);

  // Blocks per move (agent movement speed)
  uint256 constant BLOCKS_PER_MOVE = 1;

  function run() public broadcast returns (Deabstracting deabstracting) {
    // Deploy Deabstracting
    deabstracting = new Deabstracting(BLOCKS_PER_MOVE);

    // Register with PUSH4ProxyFactory
    FACTORY.register(IPUSH4Proxy(address(deabstracting)));
  }
}
