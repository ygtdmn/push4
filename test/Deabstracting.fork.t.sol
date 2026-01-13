// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test, console2 } from "forge-std/Test.sol";
import { Deabstracting } from "../src/Deabstracting.sol";
import { IRealAbstraction } from "../src/interface/IRealAbstraction.sol";
import { IPUSH4Proxy } from "../src/interface/IPUSH4Proxy.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";

/**
 * @title DeabstractingForkTest
 * @notice Fork tests for the Deabstracting maze solver proxy
 * @dev Run with: forge test --match-contract DeabstractingForkTest --fork-url mainnet -vvv
 */
contract DeabstractingForkTest is Test {
  // RealAbstraction contract on mainnet
  address constant REAL_ABSTRACTION_ADDRESS = 0x3471D8aCdD789a12Aa5c07E7d32c71d7959688E8;

  Deabstracting public proxy;
  IRealAbstraction public realAbstraction;

  uint256 public constant BLOCKS_PER_MOVE = 10;

  function setUp() public {
    string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
    if (bytes(alchemyApiKey).length == 0) {
      revert("API_KEY_ALCHEMY is not set");
    }

    vm.createSelectFork({ urlOrAlias: "mainnet" });

    realAbstraction = IRealAbstraction(REAL_ABSTRACTION_ADDRESS);

    proxy = new Deabstracting(BLOCKS_PER_MOVE);
  }

  /*//////////////////////////////////////////////////////////////
                          BASIC FORK TESTS
    //////////////////////////////////////////////////////////////*/

  function test_fork_realAbstractionExists() public view {
    uint256 codeSize;
    assembly {
      codeSize := extcodesize(REAL_ABSTRACTION_ADDRESS)
    }
    assertGt(codeSize, 0, "RealAbstraction contract should exist on mainnet fork");
  }

  function test_fork_hasLineParts() public view {
    uint256 lastPart = realAbstraction.lastPart();
    assertGt(lastPart, 0, "RealAbstraction should have at least one line part");
    console2.log("Total line parts:", lastPart);
  }

  function test_fork_canFetchLinePart() public view {
    uint256 lastPart = realAbstraction.lastPart();
    require(lastPart > 0, "No line parts available");

    (address creator, uint256 field1, uint256 field2, uint256 field3, uint256 field4) = realAbstraction.linePart(0);

    console2.log("Line part 0 creator:", creator);
    console2.log("Field1:", field1);
    console2.log("Field2:", field2);
    console2.log("Field3:", field3);
    console2.log("Field4:", field4);

    // At least one field should be non-zero
    assertTrue(field1 > 0 || field2 > 0 || field3 > 0 || field4 > 0, "At least one field should be non-zero");
  }

  /*//////////////////////////////////////////////////////////////
                          MAZE DECODING TESTS
    //////////////////////////////////////////////////////////////*/

  function test_fork_canDecodeMaze() public view {
    (, uint256 field1, uint256 field2, uint256 field3, uint256 field4) = realAbstraction.linePart(0);

    bool[875] memory walls = proxy.decodeMaze(field1, field2, field3, field4);

    // Count walls
    uint256 wallCount = 0;
    for (uint256 i = 0; i < 875; i++) {
      if (walls[i]) wallCount++;
    }

    console2.log("Wall count:", wallCount);
    console2.log("Empty count:", 875 - wallCount);

    // Maze should have some walls but not be all walls
    assertGt(wallCount, 0, "Maze should have some walls");
    assertLt(wallCount, 875, "Maze should not be all walls");
  }

  function test_fork_mazeHasCorrectDimensions() public view {
    assertEq(proxy.MAZE_COLS(), 25, "Maze should have 25 columns");
    assertEq(proxy.MAZE_ROWS(), 35, "Maze should have 35 rows");
    assertEq(proxy.TOTAL_CELLS(), 875, "Total cells should be 875");
  }

  /*//////////////////////////////////////////////////////////////
                          PATHFINDING TESTS
    //////////////////////////////////////////////////////////////*/

  function test_fork_canSolveMaze() public view {
    // Find the first solvable maze
    uint256 lastPart = realAbstraction.lastPart();

    for (uint256 i = 0; i < lastPart; i++) {
      (, uint256 field1, uint256 field2, uint256 field3, uint256 field4) = realAbstraction.linePart(i);
      bool[875] memory walls = proxy.decodeMaze(field1, field2, field3, field4);
      uint16[] memory path = proxy.solveMaze(walls);

      if (path.length > 0) {
        console2.log("First solvable maze index:", i);
        console2.log("Path length:", path.length);
        assertTrue(path.length > 0, "Path should exist");
        return;
      }
    }

    // At least one maze should be solvable
    assertTrue(false, "At least one maze should be solvable");
  }

  function test_fork_pathStartsAtBottomMiddle() public view {
    // Use maze 1 which is known to be solvable
    (, uint256 field1, uint256 field2, uint256 field3, uint256 field4) = realAbstraction.linePart(1);

    bool[875] memory walls = proxy.decodeMaze(field1, field2, field3, field4);
    uint16[] memory path = proxy.solveMaze(walls);

    if (path.length > 0) {
      uint16 startCell = path[0];
      uint8 startRow = uint8(startCell / 25);
      uint8 startCol = uint8(startCell % 25);

      assertEq(startRow, 34, "Path should start at row 34 (bottom)");
      assertEq(startCol, 12, "Path should start at column 12 (middle)");
    }
  }

  function test_fork_pathEndsAtTopMiddle() public view {
    // Use maze 1 which is known to be solvable
    (, uint256 field1, uint256 field2, uint256 field3, uint256 field4) = realAbstraction.linePart(1);

    bool[875] memory walls = proxy.decodeMaze(field1, field2, field3, field4);
    uint16[] memory path = proxy.solveMaze(walls);

    if (path.length > 0) {
      uint16 endCell = path[path.length - 1];
      uint8 endRow = uint8(endCell / 25);
      uint8 endCol = uint8(endCell % 25);

      assertEq(endRow, 0, "Path should end at row 0 (top)");
      assertEq(endCol, 12, "Path should end at column 12 (middle)");
    }
  }

  function test_fork_pathDoesNotCrossWalls() public view {
    // Use maze 1 which is known to be solvable
    (, uint256 field1, uint256 field2, uint256 field3, uint256 field4) = realAbstraction.linePart(1);

    bool[875] memory walls = proxy.decodeMaze(field1, field2, field3, field4);
    uint16[] memory path = proxy.solveMaze(walls);

    for (uint256 i = 0; i < path.length; i++) {
      assertFalse(walls[path[i]], "Path should not cross walls");
    }
  }

  function test_fork_pathIsContiguous() public view {
    // Use maze 1 which is known to be solvable
    (, uint256 field1, uint256 field2, uint256 field3, uint256 field4) = realAbstraction.linePart(1);

    bool[875] memory walls = proxy.decodeMaze(field1, field2, field3, field4);
    uint16[] memory path = proxy.solveMaze(walls);

    for (uint256 i = 1; i < path.length; i++) {
      uint16 prev = path[i - 1];
      uint16 curr = path[i];

      int16 prevRow = int16(uint16(prev / 25));
      int16 prevCol = int16(uint16(prev % 25));
      int16 currRow = int16(uint16(curr / 25));
      int16 currCol = int16(uint16(curr % 25));

      int16 rowDiff = currRow - prevRow;
      int16 colDiff = currCol - prevCol;

      // Should be adjacent (differ by 1 in one dimension, 0 in the other)
      bool isAdjacent = (rowDiff == 0 && (colDiff == 1 || colDiff == -1)) ||
        (colDiff == 0 && (rowDiff == 1 || rowDiff == -1));

      assertTrue(isAdjacent, "Path should be contiguous");
    }
  }

  /*//////////////////////////////////////////////////////////////
                          PROXY INTERFACE TESTS
    //////////////////////////////////////////////////////////////*/

  function test_fork_proxyTitle() public view {
    assertEq(proxy.title(), "Deabstracting");
  }

  function test_fork_proxyDescription() public view {
    assertTrue(bytes(proxy.description()).length > 0, "Description should not be empty");
  }

  function test_fork_proxyCreator() public view {
    IPUSH4Proxy.Creator memory c = proxy.creator();
    assertEq(c.name, "Yigit Duman");
    assertEq(c.wallet, 0x28996f7DECe7E058EBfC56dFa9371825fBfa515A);
  }

  /*//////////////////////////////////////////////////////////////
                          EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/

  function test_fork_executeReturnsValidPixel() public view {
    // Use a known selector from column 0
    bytes4 selector = 0x46352900;

    bytes4 result = proxy.execute(selector);

    // Result should have same column (last byte)
    assertEq(uint8(result[3]), 0, "Column should be preserved");

    // RGB values should be valid (0-255, which bytes always are)
    console2.log("Result R:", uint8(result[0]));
    console2.log("Result G:", uint8(result[1]));
    console2.log("Result B:", uint8(result[2]));
  }

  function test_fork_executeMultipleColumns() public view {
    // Test a few different columns
    bytes4[5] memory selectors = [
      bytes4(0x46352900), // col 0
      bytes4(0x46392f01), // col 1
      bytes4(0x46322d02), // col 2
      bytes4(0x46383003), // col 3
      bytes4(0x462e3104) // col 4
    ];

    for (uint256 i = 0; i < 5; i++) {
      bytes4 result = proxy.execute(selectors[i]);
      assertEq(uint8(result[3]), i, "Column should match");
    }
  }

  /*//////////////////////////////////////////////////////////////
                          BLOCK-BASED PATH POSITION TESTS
    //////////////////////////////////////////////////////////////*/

  function test_fork_pathPositionChangesWithBlocks() public {
    // Use the last maze
    uint256 lastPart = realAbstraction.lastPart();
    (, uint256 field1, uint256 field2, uint256 field3, uint256 field4) = realAbstraction.linePart(lastPart - 1);
    bool[875] memory walls = proxy.decodeMaze(field1, field2, field3, field4);
    uint16[] memory path = proxy.solveMaze(walls);

    if (path.length < 2) return;

    vm.roll(0);
    uint256 pos1 = proxy.getCurrentPathPosition(path.length);

    vm.roll(BLOCKS_PER_MOVE);
    uint256 pos2 = proxy.getCurrentPathPosition(path.length);

    vm.roll(BLOCKS_PER_MOVE * 2);
    uint256 pos3 = proxy.getCurrentPathPosition(path.length);

    console2.log("Position at block 0:", pos1);
    console2.log("Position at block", BLOCKS_PER_MOVE, ":", pos2);
    console2.log("Position at block", BLOCKS_PER_MOVE * 2, ":", pos3);

    // Positions should increment
    assertEq(pos2, pos1 + 1, "Position should increment by 1");
    assertEq(pos3, pos1 + 2, "Position should increment by 2");
  }

  function test_fork_positionWrapsAround() public {
    // Use the last maze
    uint256 lastPart = realAbstraction.lastPart();
    (, uint256 field1, uint256 field2, uint256 field3, uint256 field4) = realAbstraction.linePart(lastPart - 1);
    bool[875] memory walls = proxy.decodeMaze(field1, field2, field3, field4);
    uint16[] memory path = proxy.solveMaze(walls);

    if (path.length == 0) return;

    // Roll to exactly the path length
    vm.roll(BLOCKS_PER_MOVE * path.length);
    uint256 wrappedPos = proxy.getCurrentPathPosition(path.length);

    assertEq(wrappedPos, 0, "Position should wrap back to 0");
  }

  /*//////////////////////////////////////////////////////////////
                          VISUAL DEBUGGING TESTS
    //////////////////////////////////////////////////////////////*/

  function test_fork_printMazeVisual() public view {
    (, uint256 field1, uint256 field2, uint256 field3, uint256 field4) = realAbstraction.linePart(0);

    bool[875] memory walls = proxy.decodeMaze(field1, field2, field3, field4);
    uint16[] memory path = proxy.solveMaze(walls);

    console2.log("Maze visualization (# = wall, . = empty, * = path):");
    console2.log("Path length:", path.length);

    // Create path lookup
    bool[875] memory onPath;
    for (uint256 i = 0; i < path.length; i++) {
      onPath[path[i]] = true;
    }

    // Print first 15 rows (viewport size)
    for (uint8 row = 0; row < 15; row++) {
      string memory line = "";
      for (uint8 col = 0; col < 25; col++) {
        uint16 idx = uint16(row) * 25 + col;
        if (onPath[idx]) {
          line = string.concat(line, "*");
        } else if (walls[idx]) {
          line = string.concat(line, "#");
        } else {
          line = string.concat(line, ".");
        }
      }
      console2.log(line);
    }
  }

  function test_fork_solveAllMazes() public view {
    uint256 lastPart = realAbstraction.lastPart();
    console2.log("Testing", lastPart, "mazes...");

    uint256 solvable = 0;
    uint256 unsolvable = 0;

    for (uint256 i = 0; i < lastPart; i++) {
      (, uint256 field1, uint256 field2, uint256 field3, uint256 field4) = realAbstraction.linePart(i);
      bool[875] memory walls = proxy.decodeMaze(field1, field2, field3, field4);
      uint16[] memory path = proxy.solveMaze(walls);

      if (path.length > 0) {
        solvable++;
        console2.log("Maze", i, "path length:", path.length);
      } else {
        unsolvable++;
        console2.log("Maze", i, "UNSOLVABLE");
      }
    }

    console2.log("Solvable:", solvable);
    console2.log("Unsolvable:", unsolvable);
  }

  /*//////////////////////////////////////////////////////////////
                        SVG DATA URI TEST
  //////////////////////////////////////////////////////////////*/
  /// @notice Generates and logs an SVG data URI for the proxy's current rendering
  /// @dev Run with: forge test --match-test test_fork_renderSvgDataUri -vv
  /// PUSH4 canvas is 15 wide (cols/x) × 25 tall (rows/y)
  function test_fork_renderSvgDataUri() public {
    // Roll to a block to get some path position
    vm.roll(100);
    uint256 width = 15; // rows go horizontally (x)
    uint256 height = 25; // columns go vertically (y)
    uint256 pixelSize = 20;

    // Build SVG header
    string memory svg = string(
      abi.encodePacked(
        '<svg xmlns="http://www.w3.org/2000/svg" width="',
        LibString.toString(width * pixelSize),
        '" height="',
        LibString.toString(height * pixelSize),
        '" viewBox="0 0 ',
        LibString.toString(width),
        " ",
        LibString.toString(height),
        '" shape-rendering="crispEdges">'
      )
    );

    // Get selectors - array is [column][row] where column is y (0-24) and row is x (0-14)
    bytes4[15][25] memory selectors = _getSelectors();

    // Render each pixel: x = row (0-14), y = column (0-24)
    for (uint8 y = 0; y < 25; y++) {
      // columns (vertical)
      for (uint8 x = 0; x < 15; x++) {
        // rows (horizontal)
        bytes4 selector = selectors[y][x]; // [column][row]
        bytes4 result = proxy.execute(selector);

        // Extract RGB
        string memory color = string(
          abi.encodePacked("#", LibString.toHexStringNoPrefix(abi.encodePacked(result[0], result[1], result[2])))
        );

        // Add rect at (x, y)
        svg = string(
          abi.encodePacked(
            svg,
            '<rect x="',
            LibString.toString(x),
            '" y="',
            LibString.toString(y),
            '" width="1" height="1" fill="',
            color,
            '"/>'
          )
        );
      }
    }

    svg = string(abi.encodePacked(svg, "</svg>"));

    // Base64 encode
    string memory dataUri = string(abi.encodePacked("data:image/svg+xml;base64,", Base64.encode(bytes(svg))));

    console2.log("SVG Data URI:");
    console2.log(dataUri);
  }

  /// @notice Returns the selector mapping for the 15x25 grid
  /// @dev Array is [row][col] where row is y (0-24) and col is x (0-14)
  function _getSelectors() internal pure returns (bytes4[15][25] memory selectors) {
    // Row 0 (y=0): cols 0-14
    selectors[0][0] = 0x46352900;
    selectors[0][1] = 0x46392f01;
    selectors[0][2] = 0x46322d02;
    selectors[0][3] = 0x46383003;
    selectors[0][4] = 0x462e3104;
    selectors[0][5] = 0x46343205;
    selectors[0][6] = 0x46302d06;
    selectors[0][7] = 0xa6553907;
    selectors[0][8] = 0x462f3108;
    selectors[0][9] = 0x46352f09;
    selectors[0][10] = 0x4632300a;
    selectors[0][11] = 0x46382e0b;
    selectors[0][12] = 0x46322f0c;
    selectors[0][13] = 0x482f2e0d;
    selectors[0][14] = 0x46332f0e;

    // Row 1 (y=1): cols 0-14
    selectors[1][0] = 0x46362800;
    selectors[1][1] = 0x472f2a01;
    selectors[1][2] = 0x46362e02;
    selectors[1][3] = 0x47323303;
    selectors[1][4] = 0x46342c04;
    selectors[1][5] = 0x46362e05;
    selectors[1][6] = 0x46323106;
    selectors[1][7] = 0xa65c3307;
    selectors[1][8] = 0x46303208;
    selectors[1][9] = 0x47352e09;
    selectors[1][10] = 0x48322d0a;
    selectors[1][11] = 0x4639330b;
    selectors[1][12] = 0x4632320c;
    selectors[1][13] = 0x482f2f0d;
    selectors[1][14] = 0x472e310e;

    // Row 2 (y=2): cols 0-14
    selectors[2][0] = 0x46372c00;
    selectors[2][1] = 0x47343001;
    selectors[2][2] = 0x46383102;
    selectors[2][3] = 0x48302903;
    selectors[2][4] = 0x48312b04;
    selectors[2][5] = 0x46392d05;
    selectors[2][6] = 0x47312c06;
    selectors[2][7] = 0xa6613d07;
    selectors[2][8] = 0x46323108;
    selectors[2][9] = 0x48302d09;
    selectors[2][10] = 0x4834300a;
    selectors[2][11] = 0x472e2e0b;
    selectors[2][12] = 0x46342f0c;
    selectors[2][13] = 0x48302d0d;
    selectors[2][14] = 0x48302c0e;

    // Row 3 (y=3): cols 0-14
    selectors[3][0] = 0x46393300;
    selectors[3][1] = 0x482f2f01;
    selectors[3][2] = 0x472e2b02;
    selectors[3][3] = 0x48322803;
    selectors[3][4] = 0x48322c04;
    selectors[3][5] = 0x47322c05;
    selectors[3][6] = 0x47312e06;
    selectors[3][7] = 0xa7553807;
    selectors[3][8] = 0x47392d08;
    selectors[3][9] = 0x48332f09;
    selectors[3][10] = 0x48362d0a;
    selectors[3][11] = 0x472f2a0b;
    selectors[3][12] = 0x46362c0c;
    selectors[3][13] = 0x4835280d;
    selectors[3][14] = 0x48302d0e;

    // Row 4 (y=4): cols 0-14
    selectors[4][0] = 0x47313200;
    selectors[4][1] = 0x48323101;
    selectors[4][2] = 0x47312f02;
    selectors[4][3] = 0x48332f03;
    selectors[4][4] = 0x48362904;
    selectors[4][5] = 0x482e2d05;
    selectors[4][6] = 0x48313306;
    selectors[4][7] = 0xa9563607;
    selectors[4][8] = 0x49392e08;
    selectors[4][9] = 0x48362d09;
    selectors[4][10] = 0x49302f0a;
    selectors[4][11] = 0x47362a0b;
    selectors[4][12] = 0x4637330c;
    selectors[4][13] = 0x48362e0d;
    selectors[4][14] = 0x4831330e;

    // Row 5 (y=5): cols 0-14
    selectors[5][0] = 0x47372900;
    selectors[5][1] = 0x48363001;
    selectors[5][2] = 0x47332b02;
    selectors[5][3] = 0x48352c03;
    selectors[5][4] = 0x48362e04;
    selectors[5][5] = 0x482e3205;
    selectors[5][6] = 0x49303106;
    selectors[5][7] = 0xa9563a07;
    selectors[5][8] = 0x4a2e2b08;
    selectors[5][9] = 0x492f2f09;
    selectors[5][10] = 0x4935310a;
    selectors[5][11] = 0x482f2b0b;
    selectors[5][12] = 0x4731310c;
    selectors[5][13] = 0x48362f0d;
    selectors[5][14] = 0x48332b0e;

    // Row 6 (y=6): cols 0-14
    selectors[6][0] = 0x48392900;
    selectors[6][1] = 0x492e2801;
    selectors[6][2] = 0x47353102;
    selectors[6][3] = 0x48352e03;
    selectors[6][4] = 0x49333104;
    selectors[6][5] = 0x49303005;
    selectors[6][6] = 0x49382806;
    selectors[6][7] = 0xaa543107;
    selectors[6][8] = 0x4a322f08;
    selectors[6][9] = 0x49353309;
    selectors[6][10] = 0x4938320a;
    selectors[6][11] = 0x4934310b;
    selectors[6][12] = 0x4731330c;
    selectors[6][13] = 0x4839310d;
    selectors[6][14] = 0x4932300e;

    // Row 7 (y=7): cols 0-14
    selectors[7][0] = 0x4a302c00;
    selectors[7][1] = 0x49332901;
    selectors[7][2] = 0x47392902;
    selectors[7][3] = 0x49312a03;
    selectors[7][4] = 0x49352804;
    selectors[7][5] = 0x49392a05;
    selectors[7][6] = 0x49392806;
    selectors[7][7] = 0xaa553d07;
    selectors[7][8] = 0x4b333308;
    selectors[7][9] = 0x4b353009;
    selectors[7][10] = 0x4a2e2c0a;
    selectors[7][11] = 0x4a312e0b;
    selectors[7][12] = 0x48302a0c;
    selectors[7][13] = 0x4a38330d;
    selectors[7][14] = 0x4a35320e;

    // Row 8 (y=8): cols 0-14
    selectors[8][0] = 0x4a342900;
    selectors[8][1] = 0x49343001;
    selectors[8][2] = 0x49352802;
    selectors[8][3] = 0x49323103;
    selectors[8][4] = 0x49383204;
    selectors[8][5] = 0x4a2e2905;
    selectors[8][6] = 0x4a323206;
    selectors[8][7] = 0xaa5b3307;
    selectors[8][8] = 0x4c313208;
    selectors[8][9] = 0x4b372d09;
    selectors[8][10] = 0x4a302a0a;
    selectors[8][11] = 0x4b2e2f0b;
    selectors[8][12] = 0x4831280c;
    selectors[8][13] = 0x4b302e0d;
    selectors[8][14] = 0x4b2e320e;

    // Row 9 (y=9): cols 0-14
    selectors[9][0] = 0x4b332e00;
    selectors[9][1] = 0x4a382c01;
    selectors[9][2] = 0x49373102;
    selectors[9][3] = 0x49332d03;
    selectors[9][4] = 0x4a303304;
    selectors[9][5] = 0x4a312a05;
    selectors[9][6] = 0x4b322e06;
    selectors[9][7] = 0xab5d3a07;
    selectors[9][8] = 0x4c322a08;
    selectors[9][9] = 0x4b383209;
    selectors[9][10] = 0x4a332f0a;
    selectors[9][11] = 0x4b30330b;
    selectors[9][12] = 0x4833300c;
    selectors[9][13] = 0x4b332e0d;
    selectors[9][14] = 0x4b312d0e;

    // Row 10 (y=10): cols 0-14
    selectors[10][0] = 0x4b353200;
    selectors[10][1] = 0x4a393201;
    selectors[10][2] = 0x4b2e2e02;
    selectors[10][3] = 0x4a352803;
    selectors[10][4] = 0x4a342b04;
    selectors[10][5] = 0x4a362905;
    selectors[10][6] = 0x4b332a06;
    selectors[10][7] = 0xac563d07;
    selectors[10][8] = 0x4d343108;
    selectors[10][9] = 0x4b392b09;
    selectors[10][10] = 0x4a372b0a;
    selectors[10][11] = 0x4d362d0b;
    selectors[10][12] = 0x4933290c;
    selectors[10][13] = 0x4b37320d;
    selectors[10][14] = 0x4b31300e;

    // Row 11 (y=11): cols 0-14
    selectors[11][0] = 0x4c2e3200;
    selectors[11][1] = 0x4c352b01;
    selectors[11][2] = 0x4b362e02;
    selectors[11][3] = 0x4a382803;
    selectors[11][4] = 0x4a392a04;
    selectors[11][5] = 0x4a392e05;
    selectors[11][6] = 0x4b343006;
    selectors[11][7] = 0xad5d3207;
    selectors[11][8] = 0x4d372a08;
    selectors[11][9] = 0x4c2e2d09;
    selectors[11][10] = 0x4b39320a;
    selectors[11][11] = 0x4d372a0b;
    selectors[11][12] = 0x4a382e0c;
    selectors[11][13] = 0x4c2e2f0d;
    selectors[11][14] = 0x4b36310e;

    // Row 12 (y=12): cols 0-14
    selectors[12][0] = 0x4c2f3100;
    selectors[12][1] = 0x4d2f2801;
    selectors[12][2] = 0x4c342802;
    selectors[12][3] = 0x4c343103;
    selectors[12][4] = 0x4b382d04;
    selectors[12][5] = 0x4b332905;
    selectors[12][6] = 0x4c342b06;
    selectors[12][7] = 0xad613207;
    selectors[12][8] = 0x4d392908;
    selectors[12][9] = 0x4c363309;
    selectors[12][10] = 0x4c2f300a;
    selectors[12][11] = 0x4d372f0b;
    selectors[12][12] = 0x4b30310c;
    selectors[12][13] = 0x4c2f290d;
    selectors[12][14] = 0x4c33290e;

    // Row 13 (y=13): cols 0-14
    selectors[13][0] = 0x4c322c00;
    selectors[13][1] = 0x4d363101;
    selectors[13][2] = 0x4c352a02;
    selectors[13][3] = 0x4c372e03;
    selectors[13][4] = 0x4c312b04;
    selectors[13][5] = 0x4b383205;
    selectors[13][6] = 0x4c342e06;
    selectors[13][7] = 0xaf623c07;
    selectors[13][8] = 0x4d392c08;
    selectors[13][9] = 0x4c382809;
    selectors[13][10] = 0x4c302c0a;
    selectors[13][11] = 0x4d382e0b;
    selectors[13][12] = 0x4b33290c;
    selectors[13][13] = 0x4c33310d;
    selectors[13][14] = 0x4d34330e;

    // Row 14 (y=14): cols 0-14
    selectors[14][0] = 0x4c392800;
    selectors[14][1] = 0x4e2e2b01;
    selectors[14][2] = 0x4c382802;
    selectors[14][3] = 0x4e2f2d03;
    selectors[14][4] = 0x4c343204;
    selectors[14][5] = 0x4c302b05;
    selectors[14][6] = 0x4c382c06;
    selectors[14][7] = 0xb05a3b07;
    selectors[14][8] = 0x4e2f3208;
    selectors[14][9] = 0x4e322a09;
    selectors[14][10] = 0x4c38300a;
    selectors[14][11] = 0x4e312d0b;
    selectors[14][12] = 0x4b372b0c;
    selectors[14][13] = 0x4d352c0d;
    selectors[14][14] = 0x4d39320e;

    // Row 15 (y=15)
    selectors[15][0] = 0x4f302900;
    selectors[15][1] = 0x4e323301;
    selectors[15][2] = 0x4c382902;
    selectors[15][3] = 0x4e373303;
    selectors[15][4] = 0x4c372a04;
    selectors[15][5] = 0x4d312905;
    selectors[15][6] = 0x4d322a06;
    selectors[15][7] = 0xb1543d07;
    selectors[15][8] = 0x4e312a08;
    selectors[15][9] = 0x4e332a09;
    selectors[15][10] = 0x4d2f2e0a;
    selectors[15][11] = 0x4e32280b;
    selectors[15][12] = 0x4b37310c;
    selectors[15][13] = 0x4e2e330d;
    selectors[15][14] = 0x4e2f280e;

    // Row 16 (y=16)
    selectors[16][0] = 0x4f362900;
    selectors[16][1] = 0x4e363201;
    selectors[16][2] = 0x4d352802;
    selectors[16][3] = 0x4f2e2903;
    selectors[16][4] = 0x4d302a04;
    selectors[16][5] = 0x4d333205;
    selectors[16][6] = 0x4d392f06;
    selectors[16][7] = 0xb1613707;
    selectors[16][8] = 0x4f352d08;
    selectors[16][9] = 0x4e393109;
    selectors[16][10] = 0x4e2f2d0a;
    selectors[16][11] = 0x4e322d0b;
    selectors[16][12] = 0x4c2f2b0c;
    selectors[16][13] = 0x4e392a0d;
    selectors[16][14] = 0x4e32280e;

    // Row 17 (y=17)
    selectors[17][0] = 0x4f373100;
    selectors[17][1] = 0x4f312d01;
    selectors[17][2] = 0x4e333202;
    selectors[17][3] = 0x4f312b03;
    selectors[17][4] = 0x4d393304;
    selectors[17][5] = 0x4e2f3205;
    selectors[17][6] = 0x4f2f2e06;
    selectors[17][7] = 0xb2583507;
    selectors[17][8] = 0x4f363008;
    selectors[17][9] = 0x4f323209;
    selectors[17][10] = 0x4e362f0a;
    selectors[17][11] = 0x4f2f2a0b;
    selectors[17][12] = 0x4c2f310c;
    selectors[17][13] = 0x4f37330d;
    selectors[17][14] = 0x4e372c0e;

    // Row 18 (y=18)
    selectors[18][0] = 0x502f2a00;
    selectors[18][1] = 0x4f332e01;
    selectors[18][2] = 0x50332a02;
    selectors[18][3] = 0x4f362903;
    selectors[18][4] = 0x4e2f3304;
    selectors[18][5] = 0x4e303305;
    selectors[18][6] = 0x4f312906;
    selectors[18][7] = 0xb25e3b07;
    selectors[18][8] = 0x4f372a08;
    selectors[18][9] = 0x4f343209;
    selectors[18][10] = 0x4f33280a;
    selectors[18][11] = 0x4f33300b;
    selectors[18][12] = 0x4c382c0c;
    selectors[18][13] = 0x4f392d0d;
    selectors[18][14] = 0x4f2f2d0e;

    // Row 19 (y=19)
    selectors[19][0] = 0x50303200;
    selectors[19][1] = 0x4f352e01;
    selectors[19][2] = 0x50342b02;
    selectors[19][3] = 0x4f362f03;
    selectors[19][4] = 0x4e322f04;
    selectors[19][5] = 0x4e332905;
    selectors[19][6] = 0x4f313006;
    selectors[19][7] = 0xb35c3907;
    selectors[19][8] = 0x50303208;
    selectors[19][9] = 0x502e2909;
    selectors[19][10] = 0x4f372c0a;
    selectors[19][11] = 0x4f352a0b;
    selectors[19][12] = 0x4c39300c;
    selectors[19][13] = 0x50382c0d;
    selectors[19][14] = 0x4f30310e;

    // Row 20 (y=20)
    selectors[20][0] = 0x50313000;
    selectors[20][1] = 0x4f392a01;
    selectors[20][2] = 0x51332902;
    selectors[20][3] = 0x4f392903;
    selectors[20][4] = 0x4f302904;
    selectors[20][5] = 0x4e352c05;
    selectors[20][6] = 0x4f372c06;
    selectors[20][7] = 0xb4543307;
    selectors[20][8] = 0x50333308;
    selectors[20][9] = 0x50333209;
    selectors[20][10] = 0x4f382d0a;
    selectors[20][11] = 0x4f37300b;
    selectors[20][12] = 0x4d2e2b0c;
    selectors[20][13] = 0x512e2a0d;
    selectors[20][14] = 0x4f322b0e;

    // Row 21 (y=21)
    selectors[21][0] = 0x50342f00;
    selectors[21][1] = 0x502f3201;
    selectors[21][2] = 0x51343202;
    selectors[21][3] = 0x50382b03;
    selectors[21][4] = 0x502f2d04;
    selectors[21][5] = 0x4e392f05;
    selectors[21][6] = 0x50362b06;
    selectors[21][7] = 0xb45c3507;
    selectors[21][8] = 0x50352e08;
    selectors[21][9] = 0x51333209;
    selectors[21][10] = 0x50322f0a;
    selectors[21][11] = 0x4f392b0b;
    selectors[21][12] = 0x4d342a0c;
    selectors[21][13] = 0x51332c0d;
    selectors[21][14] = 0x4f33320e;

    // Row 22 (y=22)
    selectors[22][0] = 0x50372c00;
    selectors[22][1] = 0x51352e01;
    selectors[22][2] = 0x51363302;
    selectors[22][3] = 0x512e2f03;
    selectors[22][4] = 0x50322d04;
    selectors[22][5] = 0x4f382e05;
    selectors[22][6] = 0x512e3206;
    selectors[22][7] = 0xb45f3d07;
    selectors[22][8] = 0x512e2f08;
    selectors[22][9] = 0x51352809;
    selectors[22][10] = 0x5038320a;
    selectors[22][11] = 0x5030330b;
    selectors[22][12] = 0x4f302d0c;
    selectors[22][13] = 0x5135330d;
    selectors[22][14] = 0x5031330e;

    // Row 23 (y=23)
    selectors[23][0] = 0x51352d00;
    selectors[23][1] = 0x51363301;
    selectors[23][2] = 0x51392802;
    selectors[23][3] = 0x51352f03;
    selectors[23][4] = 0x50373004;
    selectors[23][5] = 0x512f2a05;
    selectors[23][6] = 0x51312f06;
    selectors[23][7] = 0xb5553c07;
    selectors[23][8] = 0x51332f08;
    selectors[23][9] = 0x51362c09;
    selectors[23][10] = 0x5133320a;
    selectors[23][11] = 0x5033300b;
    selectors[23][12] = 0x5037310c;
    selectors[23][13] = 0x51372d0d;
    selectors[23][14] = 0x50352e0e;

    // Row 24 (y=24)
    selectors[24][0] = 0x51362f00;
    selectors[24][1] = 0x51382d01;
    selectors[24][2] = 0x51392a02;
    selectors[24][3] = 0x51383303;
    selectors[24][4] = 0x51372e04;
    selectors[24][5] = 0x51312805;
    selectors[24][6] = 0x51383206;
    selectors[24][7] = 0xb5563d07;
    selectors[24][8] = 0x51382b08;
    selectors[24][9] = 0x51373309;
    selectors[24][10] = 0x51362c0a;
    selectors[24][11] = 0x5035330b;
    selectors[24][12] = 0x5038280c;
    selectors[24][13] = 0x5139280d;
    selectors[24][14] = 0x5135330e;
  }

  function test_fork_debugMazeOrientation() public view {
    // Test maze 1 which is solvable
    (, uint256 field1, uint256 field2, uint256 field3, uint256 field4) = realAbstraction.linePart(1);
    bool[875] memory walls = proxy.decodeMaze(field1, field2, field3, field4);
    uint16[] memory path = proxy.solveMaze(walls);

    console2.log("=== Maze 1 Debug ===");
    console2.log("Path length:", path.length);

    // Check start/end cells
    uint16 startCell = 34 * 25 + 12; // 862
    uint16 endCell = 0 * 25 + 12; // 12

    console2.log("Start (34,12) = cell", startCell, "is wall:", walls[startCell]);
    console2.log("End (0,12) = cell", endCell, "is wall:", walls[endCell]);

    if (path.length > 0) {
      console2.log("First path cell:", path[0]);
      console2.log("Last path cell:", path[path.length - 1]);

      // Show first few path positions
      for (uint256 i = 0; i < 5 && i < path.length; i++) {
        uint16 cell = path[i];
        uint16 row = cell / 25;
        uint16 col = cell % 25;
        console2.log("Path step", i, "cell", cell);
        console2.log("  -> row", row, "col", col);
      }
    }
  }

  function test_fork_checkSvgMaze() public view {
    uint256 lastPart = realAbstraction.lastPart();
    console2.log("Current block:", block.number);
    console2.log("Using last maze:", lastPart - 1);

    (, uint256 f1, uint256 f2, uint256 f3, uint256 f4) = realAbstraction.linePart(lastPart - 1);
    bool[875] memory walls = proxy.decodeMaze(f1, f2, f3, f4);
    uint16[] memory path = proxy.solveMaze(walls);

    console2.log("Path length:", path.length);
    if (path.length == 0) {
      console2.log("MAZE IS UNSOLVABLE - no path will render!");
    }
  }

  /*//////////////////////////////////////////////////////////////
                      SVG SEQUENCE GENERATOR
  //////////////////////////////////////////////////////////////*/

  /// @notice Generates SVG files for entire maze traversal (uses the last maze)
  /// @dev Run with: forge test --match-test test_fork_generateSvgSequence -vvv --ffi --gas-limit 200000000000 --memory-limit 2147483648
  function test_fork_generateSvgSequence() public {
    // Always use the last maze
    uint256 lastPart = realAbstraction.lastPart();
    uint256 mazeIndex = lastPart - 1;

    // Get maze and solve it first to know path length
    (, uint256 f1, uint256 f2, uint256 f3, uint256 f4) = realAbstraction.linePart(mazeIndex);
    bool[875] memory walls = proxy.decodeMaze(f1, f2, f3, f4);
    uint16[] memory path = proxy.solveMaze(walls);

    require(path.length > 0, "Maze must be solvable");

    // Start at block 0 for path position 0
    uint256 baseBlock = 0;
    vm.roll(baseBlock);

    console2.log("=== SVG Generation ===");
    console2.log("Maze index (last):", mazeIndex);
    console2.log("Path length:", path.length);
    console2.log("Base block:", baseBlock);
    console2.log("Path position:", proxy.getCurrentPathPosition(path.length));

    // Create svgs directory (will fail silently if exists)
    try vm.createDir("svgs", true) {} catch {}

    uint256 width = 15;
    uint256 height = 25;
    uint256 pixelSize = 20;
    bytes4[15][25] memory selectors = _getSelectors();

    for (uint256 step = 0; step < path.length; step++) {
      // Warp to block for this step
      vm.roll(baseBlock + step * BLOCKS_PER_MOVE);

      // Build SVG - using explicit pixel coordinates for ImageMagick compatibility
      string memory svg = string(
        abi.encodePacked(
          '<svg xmlns="http://www.w3.org/2000/svg" width="',
          LibString.toString(width * pixelSize),
          '" height="',
          LibString.toString(height * pixelSize),
          '" shape-rendering="crispEdges">',
          '<rect width="100%" height="100%" fill="#000000"/>'
        )
      );

      // Render each pixel with explicit pixel sizes
      for (uint8 y = 0; y < 25; y++) {
        for (uint8 x = 0; x < 15; x++) {
          bytes4 selector = selectors[y][x];
          bytes4 result = proxy.execute(selector);

          // Skip black pixels (already have black background)
          if (result[0] == 0 && result[1] == 0 && result[2] == 0) continue;

          string memory color = string(
            abi.encodePacked("#", LibString.toHexStringNoPrefix(abi.encodePacked(result[0], result[1], result[2])))
          );

          svg = string(
            abi.encodePacked(
              svg,
              '<rect x="',
              LibString.toString(uint256(x) * pixelSize),
              '" y="',
              LibString.toString(uint256(y) * pixelSize),
              '" width="20" height="20" fill="',
              color,
              '"/>'
            )
          );
        }
      }

      svg = string(abi.encodePacked(svg, "</svg>"));

      // Write file: svgs/step_000.svg, step_001.svg, etc.
      string memory filename = string(abi.encodePacked("svgs/step_", _padNumber(step, 3), ".svg"));

      vm.writeFile(filename, svg);

      if (step % 10 == 0) {
        console2.log("Generated step", step);
      }
    }

    console2.log("Done! Generated", path.length, "SVGs in svgs/ folder");
  }

  /// @notice Pads a number with leading zeros
  function _padNumber(uint256 num, uint256 width) internal pure returns (string memory) {
    string memory s = LibString.toString(num);
    while (bytes(s).length < width) {
      s = string(abi.encodePacked("0", s));
    }
    return s;
  }

  /*//////////////////////////////////////////////////////////////
                          GAS METERING TEST
  //////////////////////////////////////////////////////////////*/

  /// @notice Measures gas usage for executing all 375 pixels (one full frame)
  /// @dev Run with: forge test --match-test test_fork_GasMetering --fork-url mainnet -vvv
  function test_fork_GasMetering() public {
    vm.pauseGasMetering();

    // Roll to a block to get some path position
    vm.roll(100);

    // Get all selectors
    bytes4[15][25] memory selectors = _getSelectors();

    vm.resumeGasMetering();

    // Execute all 375 selectors (15 cols x 25 rows)
    for (uint8 y = 0; y < 25; y++) {
      for (uint8 x = 0; x < 15; x++) {
        proxy.execute(selectors[y][x]);
      }
    }

    vm.pauseGasMetering();
    console2.log("Executed 375 pixels (one full frame)");
    vm.resumeGasMetering();
  }
}
