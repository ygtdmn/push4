// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { IPUSH4Proxy } from "./interface/IPUSH4Proxy.sol";
import { ICryptopunksData } from "./interface/ICryptopunksData.sol";
import { PUSH4Lib } from "./libraries/PUSH4Lib.sol";

/**
 * @title PUNKS4
 * @author Yigit Duman
 * @notice A PUSH4 proxy that randomly wanders through 100x100 CryptoPunks grid, one punk per block
 */
contract PUNKS4 is IPUSH4Proxy {
    ICryptopunksData public constant CRYPTOPUNKS_DATA = ICryptopunksData(0x16F5A35647D6F03D5D3da7b35409D65ba03aF3B2);

    uint16 public constant PUNK_SIZE = 24; // Each punk is 24x24 pixels
    uint16 public constant GRID_SIZE = 100; // 100x100 punk grid
    uint8 public constant VIEWPORT_COLS = 15;
    uint8 public constant VIEWPORT_ROWS = 25;

    // Cryptopunks grid background color
    uint8 public constant BG_R = 0x63; // 99
    uint8 public constant BG_G = 0x85; // 133
    uint8 public constant BG_B = 0x96; // 150

    uint256 public immutable seed;

    constructor() {
        seed = uint256(blockhash(block.number - 1));
    }

    /**
     * @notice Calculate the agent's current position using random walk
     * @return x The x coordinate of the viewport's top-left corner (pixel position)
     * @return y The y coordinate of the viewport's top-left corner (pixel position)
     */
    function getAgentPosition() public view returns (uint16 x, uint16 y) {
        // Genereate a pseudo-random uint256 based on seed and block number
        uint256 rand = uint256(keccak256(abi.encodePacked(seed, block.number)));

        // Generate punk coordinates (0-99 for each axis)
        uint16 punkX = uint16(rand % GRID_SIZE);
        uint16 punkY = uint16((rand >> 128) % GRID_SIZE);

        // Center viewport on the current punk
        uint16 punkCenterX = punkX * PUNK_SIZE + PUNK_SIZE / 2;
        uint16 punkCenterY = punkY * PUNK_SIZE + PUNK_SIZE / 2;

        // Calculate top-left corner of viewport to center on punk
        int16 viewX = int16(punkCenterX) - int16(uint16(VIEWPORT_COLS) / 2);
        int16 viewY = int16(punkCenterY) - int16(uint16(VIEWPORT_ROWS) / 2);

        // Clamp to world bounds
        uint16 maxX = GRID_SIZE * PUNK_SIZE - VIEWPORT_COLS;
        uint16 maxY = GRID_SIZE * PUNK_SIZE - VIEWPORT_ROWS;

        if (viewX < 0) viewX = 0;
        if (viewY < 0) viewY = 0;
        if (viewX > int16(maxX)) viewX = int16(maxX);
        if (viewY > int16(maxY)) viewY = int16(maxY);

        x = uint16(viewX);
        y = uint16(viewY);
    }

    /**
     * @notice Get the RGB color at a specific world coordinate
     * @param worldX The x coordinate in the world
     * @param worldY The y coordinate in the world
     * @return r Red component
     * @return g Green component
     * @return b Blue component
     */
    function getPixelColor(uint16 worldX, uint16 worldY) public view returns (uint8 r, uint8 g, uint8 b) {
        // Which punk contains this pixel?
        uint16 punkCol = worldX / PUNK_SIZE; // 0-99
        uint16 punkRow = worldY / PUNK_SIZE; // 0-99
        uint16 punkIndex = punkRow * GRID_SIZE + punkCol; // 0-9999

        // Position within the punk (0-23, 0-23)
        uint8 pixelX = uint8(worldX % PUNK_SIZE);
        uint8 pixelY = uint8(worldY % PUNK_SIZE);

        // Fetch punk image data (2304 bytes = 24x24x4 RGBA)
        bytes memory pixels = CRYPTOPUNKS_DATA.punkImage(punkIndex);

        // Extract RGBA at position (pixelY * 24 + pixelX) * 4
        uint256 offset = (uint256(pixelY) * 24 + uint256(pixelX)) * 4;

        // Check alpha channel - return background color for transparent pixels
        uint8 alpha = uint8(pixels[offset + 3]);
        if (alpha == 0) {
            return (BG_R, BG_G, BG_B);
        }

        r = uint8(pixels[offset]);
        g = uint8(pixels[offset + 1]);
        b = uint8(pixels[offset + 2]);
    }

    /**
     * @notice Execute the proxy for a given selector
     * @param selector The function selector containing RGB and column data
     * @return The new selector with pixel data from the Cryptopunks world
     */
    function execute(bytes4 selector) external view override returns (bytes4) {
        uint8 col = uint8(selector[3]); // 0-14
        uint8 viewportRow = PUSH4Lib.getRenderRow(selector, col); // 0-24

        // Get agent's top-left position
        (uint16 agentX, uint16 agentY) = getAgentPosition();

        // Calculate world coordinates for this viewport pixel
        uint16 worldX = agentX + col;
        uint16 worldY = agentY + viewportRow;

        // Get pixel color from the appropriate punk
        (uint8 r, uint8 g, uint8 b) = getPixelColor(worldX, worldY);

        return bytes4(bytes.concat(bytes1(r), bytes1(g), bytes1(b), bytes1(col)));
    }

    function title() external pure override returns (string memory) {
        return "Wandering Punks";
    }

    function description() external pure override returns (string memory) {
        return "An agent randomly wandering through 100x100 CryptoPunks grid, one punk per block";
    }

    function creator() external pure override returns (Creator memory) {
        return Creator({ name: "Yigit Duman", wallet: address(0x28996f7DECe7E058EBfC56dFa9371825fBfa515A) });
    }
}
