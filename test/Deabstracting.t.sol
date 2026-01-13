// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test, console2 } from "forge-std/Test.sol";
import { Deabstracting } from "../src/Deabstracting.sol";

contract DeabstractingUnitTest is Test {
  Deabstracting public proxy;

  function setUp() public {
    proxy = new Deabstracting(10);
  }

  function test_solveMaze_empty() public view {
    // Empty maze (no walls)
    bool[875] memory walls;
    uint16[] memory path = proxy.solveMaze(walls);
    console2.log("Path length:", path.length);
    assertTrue(path.length > 0, "Should find a path in empty maze");
  }

  function test_solveMaze_withObstacles() public view {
    // Maze with a horizontal wall but with gaps
    bool[875] memory walls;
    // Add a wall across row 17 except at column 12
    for (uint16 col = 0; col < 25; col++) {
      if (col != 12) {
        walls[17 * 25 + col] = true;
      }
    }

    uint16[] memory path = proxy.solveMaze(walls);
    console2.log("Path length with obstacles:", path.length);
    assertTrue(path.length > 0, "Should find a path through the gap");
  }

  function test_decodeMaze_basic() public view {
    // Test with zero values - should have no walls
    bool[875] memory walls = proxy.decodeMaze(0, 0, 0, 0);

    uint256 wallCount = 0;
    for (uint256 i = 0; i < 875; i++) {
      if (walls[i]) wallCount++;
    }

    assertEq(wallCount, 0, "Zero fields should have no walls");
  }

  function test_decodeMaze_singleBit() public view {
    // Test with field1 having bit 0 set (should appear at position 252)
    bool[875] memory walls = proxy.decodeMaze(1, 0, 0, 0);

    assertTrue(walls[252], "Bit 0 of field1 should set wall at position 252");

    // Count total walls
    uint256 wallCount = 0;
    for (uint256 i = 0; i < 875; i++) {
      if (walls[i]) wallCount++;
    }
    assertEq(wallCount, 1, "Should have exactly 1 wall");
  }
}
