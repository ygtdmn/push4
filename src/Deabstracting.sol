// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { IPUSH4Proxy } from "./interface/IPUSH4Proxy.sol";
import { IRealAbstraction } from "./interface/IRealAbstraction.sol";
import { PUSH4Lib } from "./libraries/PUSH4Lib.sol";
import { Ownable } from "solady/auth/Ownable.sol";

/**
 * @title Deabstracting
 * @author Yigit Duman
 * @notice A PUSH4 proxy that renders an agent traversing Paul Seidler's Real Abstraction mazes.
 *         Uses BFS pathfinding and displays a scrolling 15x25 viewport centered on the agent.
 */
contract Deabstracting is IPUSH4Proxy, Ownable {
  IRealAbstraction public constant REAL_ABSTRACTION = IRealAbstraction(0x3471D8aCdD789a12Aa5c07E7d32c71d7959688E8);

  uint8 public constant MAZE_COLS = 25;
  uint8 public constant MAZE_ROWS = 35;

  uint8 public constant VIEWPORT_COLS = 15;
  uint8 public constant VIEWPORT_ROWS = 25;

  uint16 public constant TOTAL_CELLS = 875; // 25 * 35

  // Pathfinding constants
  uint8 public constant START_COL = 12; // Bottom middle
  uint8 public constant START_ROW = 34;
  uint8 public constant END_COL = 12; // Top middle
  uint8 public constant END_ROW = 0;

  // Movement timing
  uint256 public blocksPerMove;

  constructor(uint256 _blocksPerMove) {
    _initializeOwner(msg.sender);
    blocksPerMove = _blocksPerMove;
  }

  function setBlocksPerMove(uint256 _blocksPerMove) external onlyOwner {
    blocksPerMove = _blocksPerMove;
  }

  function title() external pure returns (string memory) {
    return "Deabstracting";
  }

  function description() external pure returns (string memory) {
    return "A PUSH4 proxy that renders an agent traversing Paul Seidler's Real Abstraction mazes.";
  }

  function creator() external pure returns (Creator memory) {
    return Creator({ name: "Yigit Duman", wallet: 0x28996f7DECe7E058EBfC56dFa9371825fBfa515A });
  }

  function execute(bytes4 selector) external view returns (bytes4) {
    uint8 col = uint8(selector[3]);
    uint8 viewportRow = PUSH4Lib.getRenderRow(selector, col);

    return _computePixel(col, viewportRow);
  }

  function _computePixel(uint8 col, uint8 viewportRow) internal view returns (bytes4) {
    uint256 lastPart = REAL_ABSTRACTION.lastPart();

    if (lastPart == 0) {
      return bytes4(bytes.concat(bytes1(0), bytes1(0), bytes1(0), bytes1(col)));
    }

    // Fetch and decode maze
    (, uint256 f1, uint256 f2, uint256 f3, uint256 f4) = REAL_ABSTRACTION.linePart(lastPart - 1);
    bool[875] memory walls = decodeMaze(f1, f2, f3, f4);

    // Solve and get path
    uint16[] memory path = solveMaze(walls);
    uint256 pathPos = getCurrentPathPosition(path.length);

    // Compute colors
    return _renderPixel(col, viewportRow, walls, path, pathPos);
  }

  function _renderPixel(
    uint8 col,
    uint8 viewportRow,
    bool[875] memory walls,
    uint16[] memory path,
    uint256 pathPos
  ) internal pure returns (bytes4) {
    (uint8 colOffset, uint8 rowOffset) = getCameraOffsets(path, pathPos);
    uint8 mazeCol = col + colOffset;
    uint8 mazeRow = viewportRow + rowOffset;

    (uint8 r, uint8 g, uint8 b) = getPixelColor(mazeCol, mazeRow, walls, path, pathPos);

    return bytes4(bytes.concat(bytes1(r), bytes1(g), bytes1(b), bytes1(col)));
  }

  /*//////////////////////////////////////////////////////////////
                            MAZE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /// @notice Get the current position on the path
  function getCurrentPathPosition(uint256 pathLength) public view returns (uint256) {
    if (pathLength == 0) return 0;
    return (block.number / blocksPerMove) % pathLength;
  }

  /// @notice Calculate camera offsets to keep agent centered in viewport
  /// @dev Returns (colOffset, rowOffset) for a 15x25 viewport on 25x35 maze
  function getCameraOffsets(
    uint16[] memory path,
    uint256 pathPosition
  ) internal pure returns (uint8 colOffset, uint8 rowOffset) {
    if (path.length == 0) return (0, 0);

    uint16 currentCell = path[pathPosition];
    uint8 agentCol = uint8(currentCell % MAZE_COLS); // 0-24
    uint8 agentRow = uint8(currentCell / MAZE_COLS); // 0-34

    // Horizontal: center agent at col 7 of 15-col viewport
    int16 targetColOffset = int16(uint16(agentCol)) - 7;
    if (targetColOffset < 0) {
      colOffset = 0;
    } else if (targetColOffset > 10) {
      colOffset = 10; // 25-15=10 max horizontal scroll
    } else {
      colOffset = uint8(uint16(targetColOffset));
    }

    // Vertical: center agent at row 12 of 25-row viewport
    int16 targetRowOffset = int16(uint16(agentRow)) - 12;
    if (targetRowOffset < 0) {
      rowOffset = 0;
    } else if (targetRowOffset > 10) {
      rowOffset = 10; // 35-25=10 max vertical scroll
    } else {
      rowOffset = uint8(uint16(targetRowOffset));
    }
  }

  /// @notice Decode 4 uint256 fields into a wall grid
  function decodeMaze(
    uint256 field1,
    uint256 field2,
    uint256 field3,
    uint256 field4
  ) public pure returns (bool[875] memory walls) {
    // The JavaScript decoding:
    // 1. For each field, read 253 bits (except field4 which contributes remaining)
    // 2. Bit i in the field maps to array position (252 - i)
    // 3. All 4 arrays concatenated give 1012 bits, first 875 used for the grid

    uint256[4] memory fields = [field1, field2, field3, field4];

    for (uint256 fieldIdx = 0; fieldIdx < 4; fieldIdx++) {
      uint256 field = fields[fieldIdx];
      uint256 baseIndex = fieldIdx * 253;

      // Each field contributes 253 bits
      for (uint256 i = 0; i < 253; i++) {
        uint256 arrayPos = baseIndex + (252 - i); // Matches JS: bits[252 - i] = (input >> i) & 1

        if (arrayPos < 875) {
          bool isWall = ((field >> i) & 1) == 1;
          walls[arrayPos] = isWall;
        }
      }
    }
  }

  /// @notice Solve the maze using BFS from bottom-middle to top-middle
  function solveMaze(bool[875] memory walls) public pure returns (uint16[] memory) {
    uint16 startCell = 862; // 34 * 25 + 12
    uint16 endCell = 12; // 0 * 25 + 12

    if (walls[startCell] || walls[endCell]) {
      return new uint16[](0);
    }

    // BFS data structures
    bool[875] memory visited;
    uint16[875] memory parent;
    uint16[875] memory queue;
    uint16 qHead = 0;
    uint16 qTail = 1;

    visited[startCell] = true;
    parent[startCell] = startCell;
    queue[0] = startCell;

    bool found = false;

    while (qHead < qTail && !found) {
      uint16 curr = queue[qHead];
      qHead = qHead + 1;

      uint16 row = curr / 25;
      uint16 col = curr % 25;

      // Check all 4 neighbors: up, down, left, right
      // Up
      if (row > 0) {
        uint16 next = curr - 25;
        if (!visited[next] && !walls[next]) {
          visited[next] = true;
          parent[next] = curr;
          queue[qTail] = next;
          qTail = qTail + 1;
          if (next == endCell) {
            found = true;
          }
        }
      }

      // Down
      if (!found && row < 34) {
        uint16 next = curr + 25;
        if (!visited[next] && !walls[next]) {
          visited[next] = true;
          parent[next] = curr;
          queue[qTail] = next;
          qTail = qTail + 1;
          if (next == endCell) {
            found = true;
          }
        }
      }

      // Left
      if (!found && col > 0) {
        uint16 next = curr - 1;
        if (!visited[next] && !walls[next]) {
          visited[next] = true;
          parent[next] = curr;
          queue[qTail] = next;
          qTail = qTail + 1;
          if (next == endCell) {
            found = true;
          }
        }
      }

      // Right
      if (!found && col < 24) {
        uint16 next = curr + 1;
        if (!visited[next] && !walls[next]) {
          visited[next] = true;
          parent[next] = curr;
          queue[qTail] = next;
          qTail = qTail + 1;
          if (next == endCell) {
            found = true;
          }
        }
      }
    }

    if (!found) {
      return new uint16[](0);
    }

    // Count path length
    uint16 len = 1;
    uint16 cell = endCell;
    while (cell != startCell) {
      len = len + 1;
      cell = parent[cell];
    }

    // Build path array (from start to end)
    uint16[] memory path = new uint16[](len);
    cell = endCell;
    uint16 idx = len;
    while (idx > 0) {
      idx = idx - 1;
      path[idx] = cell;
      if (cell != startCell) {
        cell = parent[cell];
      }
    }

    return path;
  }

  /// @notice Get pixel color for a given position
  function getPixelColor(
    uint8 col,
    uint8 row,
    bool[875] memory walls,
    uint16[] memory path,
    uint256 pathPosition
  ) internal pure returns (uint8 r, uint8 g, uint8 b) {
    // Out of bounds check
    if (row >= MAZE_ROWS) {
      return (0, 0, 0); // Black for out of bounds
    }

    uint16 cellIndex = uint16(row) * MAZE_COLS + col;

    // Check if this is the agent's current position
    if (path.length > 0 && path[pathPosition] == cellIndex) {
      return (255, 0, 0); // Red for agent
    }

    // Check if this cell is on the solved path
    for (uint256 i = 0; i < path.length; i++) {
      if (path[i] == cellIndex) {
        return (0, 255, 0); // Green for path
      }
    }

    // Check if wall
    if (walls[cellIndex]) {
      return (128, 128, 128); // Gray for walls
    }

    // Empty space
    return (0, 0, 0); // Black for empty
  }
}
