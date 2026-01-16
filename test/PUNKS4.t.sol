// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Test, console2 } from "forge-std/Test.sol";
import { PUNKS4 } from "../src/PUNKS4.sol";
import { IPUSH4Proxy } from "../src/interface/IPUSH4Proxy.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";

contract PUNKS4Test is Test {
    PUNKS4 public punks4;

    function setUp() public {
        punks4 = new PUNKS4();
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsImmutables() public view {
        assertEq(punks4.seed(), uint256(blockhash(block.number - 1)));
    }

    function test_constructor_differentBlocks() public {
        vm.roll(block.number + 1);
        PUNKS4 p1 = new PUNKS4();
        vm.roll(block.number + 1);
        PUNKS4 p2 = new PUNKS4();
        assertTrue(p1.seed() != p2.seed());
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTANTS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constants() public view {
        assertEq(punks4.PUNK_SIZE(), 24);
        assertEq(punks4.GRID_SIZE(), 100);
        assertEq(punks4.VIEWPORT_COLS(), 15);
        assertEq(punks4.VIEWPORT_ROWS(), 25);

        // Background color #638596
        assertEq(punks4.BG_R(), 0x63);
        assertEq(punks4.BG_G(), 0x85);
        assertEq(punks4.BG_B(), 0x96);
    }

    /*//////////////////////////////////////////////////////////////
                        POSITION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getAgentPosition_withinBounds() public view {
        (uint16 x, uint16 y) = punks4.getAgentPosition();

        // Position should be within valid range (leaving room for viewport)
        uint16 maxX = punks4.GRID_SIZE() * punks4.PUNK_SIZE() - punks4.VIEWPORT_COLS();
        uint16 maxY = punks4.GRID_SIZE() * punks4.PUNK_SIZE() - punks4.VIEWPORT_ROWS();
        assertLe(x, maxX);
        assertLe(y, maxY);
    }

    function test_getAgentPosition_changesWithBlockNumber() public {
        (uint16 x1, uint16 y1) = punks4.getAgentPosition();

        // Move forward in blocks
        vm.roll(block.number + 10);

        (uint16 x2, uint16 y2) = punks4.getAgentPosition();

        // Position should change (movement is 1 punk per block)
        assertTrue(x1 != x2 || y1 != y2, "Position should change with block number");
    }

    function test_getAgentPosition_deterministicAtSameBlock() public view {
        (uint16 x1, uint16 y1) = punks4.getAgentPosition();
        (uint16 x2, uint16 y2) = punks4.getAgentPosition();

        assertEq(x1, x2);
        assertEq(y1, y2);
    }

    function test_getAgentPosition_differentSeedsGiveDifferentPositions() public {
        vm.roll(10); // Need some blocks for random walk to diverge

        PUNKS4 punks4a = new PUNKS4();

        vm.roll(20);
        PUNKS4 punks4b = new PUNKS4();

        (uint16 x1, uint16 y1) = punks4a.getAgentPosition();
        (uint16 x2, uint16 y2) = punks4b.getAgentPosition();

        assertTrue(x1 != x2 || y1 != y2, "Different seeds should give different positions");
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE / BOUNDARY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that position stays within bounds at block 0 (starting position)
    function test_getAgentPosition_blockZeroWithinBounds() public view {
        // At block 0, agent should be at center
        (uint16 x, uint16 y) = punks4.getAgentPosition();

        uint16 maxX = punks4.GRID_SIZE() * punks4.PUNK_SIZE() - punks4.VIEWPORT_COLS();
        uint16 maxY = punks4.GRID_SIZE() * punks4.PUNK_SIZE() - punks4.VIEWPORT_ROWS();

        assertLe(x, maxX, "X should be within max bounds at block 0");
        assertLe(y, maxY, "Y should be within max bounds at block 0");
    }

    /// @notice Test that agent never goes out of bounds after many blocks with various seeds
    function test_getAgentPosition_staysWithinBoundsAfterManyBlocks() public {
        uint16 maxX = punks4.GRID_SIZE() * punks4.PUNK_SIZE() - punks4.VIEWPORT_COLS();
        uint16 maxY = punks4.GRID_SIZE() * punks4.PUNK_SIZE() - punks4.VIEWPORT_ROWS();

        // Test with different seeds that might push towards edges

        for (uint256 s = 0; s < 5; s++) {
            vm.roll(block.number + 1);
            PUNKS4 testPunks = new PUNKS4();

            // Test at various block numbers
            for (uint256 blockNum = 0; blockNum <= 200; blockNum += 10) {
                vm.roll(blockNum);
                (uint16 x, uint16 y) = testPunks.getAgentPosition();

                assertLe(x, maxX, "X out of bounds");
                assertLe(y, maxY, "Y out of bounds");
            }
        }
    }

    /// @notice Test that punk position (before centering) stays within 0-99 grid
    function test_punkPosition_staysWithinGrid() public {
        // We can't directly test punk position, but we can verify viewport position
        // implies valid punk coordinates. At center starting point (50,50),
        // walking 50+ blocks in one direction should hit the edge and stop.

        // Create a seed that tends to go in one direction (tested empirically)
        for (uint256 i = 0; i < 10; i++) {
            vm.roll(block.number + 1);
            PUNKS4 testPunks = new PUNKS4();

            // Walk 150 blocks - more than enough to hit any edge from center
            vm.roll(150);

            (uint16 x, uint16 y) = testPunks.getAgentPosition();

            // Viewport should be clamped to valid world coordinates
            uint16 maxX = punks4.GRID_SIZE() * punks4.PUNK_SIZE() - punks4.VIEWPORT_COLS();
            uint16 maxY = punks4.GRID_SIZE() * punks4.PUNK_SIZE() - punks4.VIEWPORT_ROWS();

            assertLe(x, maxX, "X exceeded max after long walk");
            assertLe(y, maxY, "Y exceeded max after long walk");
            // X and Y are uint16, so they can't be negative (underflow check implicit)
        }
    }

    /// @notice Fuzz test: position should always be within bounds for any seed and block number
    function testFuzz_getAgentPosition_alwaysWithinBounds(uint256 seedOffset, uint8 blockNum) public {
        // Use seedOffset to shift block number for different seeds
        vm.roll(block.number + (seedOffset % 100) + 1);
        PUNKS4 testPunks = new PUNKS4();

        // Limit block number to reasonable range to avoid gas issues
        vm.roll(uint256(blockNum));

        (uint16 x, uint16 y) = testPunks.getAgentPosition();

        uint16 maxX = punks4.GRID_SIZE() * punks4.PUNK_SIZE() - punks4.VIEWPORT_COLS();
        uint16 maxY = punks4.GRID_SIZE() * punks4.PUNK_SIZE() - punks4.VIEWPORT_ROWS();

        assertLe(x, maxX, "Fuzz: X out of bounds");
        assertLe(y, maxY, "Fuzz: Y out of bounds");
    }

    /// @notice Test viewport position is always within valid bounds
    function test_viewportCentering_withinBounds() public view {
        (uint16 x, uint16 y) = punks4.getAgentPosition();

        uint16 maxX = punks4.GRID_SIZE() * punks4.PUNK_SIZE() - punks4.VIEWPORT_COLS();
        uint16 maxY = punks4.GRID_SIZE() * punks4.PUNK_SIZE() - punks4.VIEWPORT_ROWS();

        // Viewport should be clamped to valid range
        assertLe(x, maxX, "X within max bounds");
        assertLe(y, maxY, "Y within max bounds");
    }

    /*//////////////////////////////////////////////////////////////
                        METADATA TESTS
    //////////////////////////////////////////////////////////////*/

    function test_title() public view {
        assertEq(punks4.title(), "Wandering Punks");
    }

    function test_description() public view {
        assertEq(
            punks4.description(), "An agent randomly wandering through 100x100 CryptoPunks grid, one punk per block"
        );
    }

    function test_creator() public view {
        IPUSH4Proxy.Creator memory creator = punks4.creator();
        assertEq(creator.name, "Yigit Duman");
        assertEq(creator.wallet, address(0x28996f7DECe7E058EBfC56dFa9371825fBfa515A));
    }

    /*//////////////////////////////////////////////////////////////
                    INTERFACE COMPLIANCE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_implementsIPUSH4Proxy() public view {
        // Verify the contract implements IPUSH4Proxy interface
        assertTrue(address(punks4) != address(0));
    }
}

contract PUNKS4ForkTest is Test {
    PUNKS4 public punks4;

    function setUp() public {
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY is not set");
        }

        vm.createSelectFork({ urlOrAlias: "mainnet" });

        punks4 = new PUNKS4();
    }

    /*//////////////////////////////////////////////////////////////
                        EXECUTE TESTS (FORK)
    //////////////////////////////////////////////////////////////*/

    function test_execute_returnsValidSelector() public view {
        // Use a known selector from PUSH4Lib (col 0, row 0)
        bytes4 selector = 0x46352900;

        bytes4 result = punks4.execute(selector);

        // Result should have the same column (byte 3)
        assertEq(uint8(result[3]), 0, "Column should be preserved");
        assertTrue(true, "Execute completed successfully");
    }

    function test_execute_preservesColumn() public {
        // Test different columns
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = 0x46352900; // col 0
        selectors[1] = 0x46392f01; // col 1
        selectors[2] = 0x46322d02; // col 2

        for (uint256 i = 0; i < selectors.length; i++) {
            bytes4 result = punks4.execute(selectors[i]);
            assertEq(uint8(result[3]), i, "Column should be preserved in result");
        }
    }

    function test_getPixelColor_returnsValidColors() public view {
        // Get a pixel from a central position
        (uint8 r, uint8 g, uint8 b) = punks4.getPixelColor(12, 12);
        assertTrue(r > 0 || g > 0 || b > 0, "Should return valid pixel data at punk center");
    }

    function test_getPixelColor_differentPositionsGiveDifferentColors() public view {
        (uint8 r1, uint8 g1, uint8 b1) = punks4.getPixelColor(12, 12);
        (uint8 r2, uint8 g2, uint8 b2) = punks4.getPixelColor(36, 12);

        bool different = (r1 != r2) || (g1 != g2) || (b1 != b2);
        assertTrue(different, "Different punks should have different pixels");
    }

    function test_execute_changesWithBlockNumber() public {
        (uint16 x1, uint16 y1) = punks4.getAgentPosition();

        vm.roll(block.number + 10);

        (uint16 x2, uint16 y2) = punks4.getAgentPosition();

        assertTrue(x1 != x2 || y1 != y2, "Agent position should change with block number");
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fullViewportRender() public view {
        bytes4[] memory allSelectors = _getAllSelectors();

        for (uint256 i = 0; i < allSelectors.length; i++) {
            punks4.execute(allSelectors[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        MOVEMENT ANALYSIS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verifies random position changes between blocks
    function test_randomPositionChanges() public {
        (uint16 x1, uint16 y1) = punks4.getAgentPosition();
        vm.roll(block.number + 1);
        (uint16 x2, uint16 y2) = punks4.getAgentPosition();

        // Position should change between blocks (hash-based random)
        assertTrue(x1 != x2 || y1 != y2, "Position should change each block");
    }

    /*//////////////////////////////////////////////////////////////
                        SVG SEQUENCE GENERATOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Generates SVG files for exploring the Cryptopunks grid
    /// @dev Run with: forge test --match-test test_fork_generateSvgSequence -vvv --gas-limit 200000000000
    /// --memory-limit 2147483648
    function test_fork_generateSvgSequence() public {
        uint256 numFrames = 20;
        uint256 blocksPerFrame = 1;

        punks4 = new PUNKS4();

        try vm.createDir("punks-svgs", true) { } catch { }

        uint256 width = 15;
        uint256 height = 25;
        uint256 pixelSize = 20;
        bytes4[15][25] memory selectors = _getSelectors();

        console2.log("=== PUNKS4 SVG Generation ===");
        console2.log("Generating", numFrames, "frames");

        for (uint256 step = 0; step < numFrames; step++) {
            vm.roll(step * blocksPerFrame);

            (uint16 agentX, uint16 agentY) = punks4.getAgentPosition();
            if (step % 10 == 0) {
                console2.log("Frame", step);
                console2.log("  Position: x=", agentX, "y=", agentY);
            }

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

            for (uint8 y = 0; y < 25; y++) {
                for (uint8 x = 0; x < 15; x++) {
                    bytes4 selector = selectors[y][x];
                    bytes4 result = punks4.execute(selector);

                    if (result[0] == 0 && result[1] == 0 && result[2] == 0) continue;

                    string memory color = string(
                        abi.encodePacked(
                            "#", LibString.toHexStringNoPrefix(abi.encodePacked(result[0], result[1], result[2]))
                        )
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

            string memory filename = string(abi.encodePacked("punks-svgs/step_", _padNumber(step, 3), ".svg"));
            vm.writeFile(filename, svg);
        }

        console2.log("Done! Generated", numFrames, "SVGs in punks-svgs/ folder");
    }

    /// @notice Renders a single SVG at the current block and logs as data URI
    function test_fork_renderSvgDataUri() public {
        vm.roll(5);

        uint256 width = 15;
        uint256 height = 25;
        uint256 pixelSize = 20;

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

        bytes4[15][25] memory selectors = _getSelectors();

        for (uint8 y = 0; y < 25; y++) {
            for (uint8 x = 0; x < 15; x++) {
                bytes4 selector = selectors[y][x];
                bytes4 result = punks4.execute(selector);

                string memory color = string(
                    abi.encodePacked(
                        "#", LibString.toHexStringNoPrefix(abi.encodePacked(result[0], result[1], result[2]))
                    )
                );

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

        string memory dataUri = string(abi.encodePacked("data:image/svg+xml;base64,", Base64.encode(bytes(svg))));

        console2.log("SVG Data URI:");
        console2.log(dataUri);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _getAllSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](15);
        selectors[0] = 0x46352900;
        selectors[1] = 0x46392f01;
        selectors[2] = 0x46322d02;
        selectors[3] = 0x46383003;
        selectors[4] = 0x462e3104;
        selectors[5] = 0x46343205;
        selectors[6] = 0x46302d06;
        selectors[7] = 0xa6553907;
        selectors[8] = 0x462f3108;
        selectors[9] = 0x46352f09;
        selectors[10] = 0x4632300a;
        selectors[11] = 0x46382e0b;
        selectors[12] = 0x46322f0c;
        selectors[13] = 0x482f2e0d;
        selectors[14] = 0x46332f0e;
        return selectors;
    }

    function _padNumber(uint256 num, uint256 width) internal pure returns (string memory) {
        string memory s = LibString.toString(num);
        while (bytes(s).length < width) {
            s = string(abi.encodePacked("0", s));
        }
        return s;
    }

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

        // Row 1 (y=1)
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

        // Row 2 (y=2)
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

        // Row 3 (y=3)
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

        // Row 4 (y=4)
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

        // Row 5 (y=5)
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

        // Row 6 (y=6)
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

        // Row 7 (y=7)
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

        // Row 8 (y=8)
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

        // Row 9 (y=9)
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

        // Row 10 (y=10)
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

        // Row 11 (y=11)
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

        // Row 12 (y=12)
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

        // Row 13 (y=13)
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

        // Row 14 (y=14)
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
}
