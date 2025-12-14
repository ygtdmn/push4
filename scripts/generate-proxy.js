#!/usr/bin/env node
/**
 * Generate PUSH4ProxyTemplate contract from a 15x25 PNG image
 * 
 * Usage: node scripts/generate-proxy.js <image.png> [output.sol]
 */

const fs = require('fs');
const path = require('path');

// Try to use sharp if available, otherwise fall back to pngjs
let imageLib = null;

async function loadImage(imagePath) {
    try {
        const sharp = require('sharp');
        const { data, info } = await sharp(imagePath)
            .raw()
            .toBuffer({ resolveWithObject: true });
        
        if (info.width !== 15 || info.height !== 25) {
            throw new Error(`Image must be 15x25, got ${info.width}x${info.height}`);
        }
        
        const pixels = [];
        const channels = info.channels;
        for (let y = 0; y < 25; y++) {
            for (let x = 0; x < 15; x++) {
                const idx = (y * 15 + x) * channels;
                pixels.push({
                    x, y,
                    r: data[idx],
                    g: data[idx + 1],
                    b: data[idx + 2]
                });
            }
        }
        return pixels;
    } catch (e) {
        if (e.code === 'MODULE_NOT_FOUND') {
            // Fallback to pngjs
            const { PNG } = require('pngjs');
            const data = fs.readFileSync(imagePath);
            const png = PNG.sync.read(data);
            
            if (png.width !== 15 || png.height !== 25) {
                throw new Error(`Image must be 15x25, got ${png.width}x${png.height}`);
            }
            
            const pixels = [];
            for (let y = 0; y < 25; y++) {
                for (let x = 0; x < 15; x++) {
                    const idx = (y * 15 + x) * 4;
                    pixels.push({
                        x, y,
                        r: png.data[idx],
                        g: png.data[idx + 1],
                        b: png.data[idx + 2]
                    });
                }
            }
            return pixels;
        }
        throw e;
    }
}

// Original selectors from PUSH4.sol in source order (row-major)
const ORIGINAL_SELECTORS = [
    "0x4f302900", "0x51363301", "0x47312f02", "0x48332f03", "0x48312b04",
    "0x4e332905", "0x50362b06", "0xb5553c07", "0x4d392c08", "0x51333209",
    "0x48322d0a", "0x4e322d0b", "0x4c2f2b0c", "0x5135330d", "0x4831330e",
    "0x4f362900", "0x4c352b01", "0x46322d02", "0x48302903", "0x4e2f3304",
    "0x4e303305", "0x4b343006", "0xb35c3907", "0x46323108", "0x4f323209",
    "0x4c302c0a", "0x46382e0b", "0x4831280c", "0x4839310d", "0x472e310e",
    "0x51352d00", "0x482f2f01", "0x51392a02", "0x4a352803", "0x462e3104",
    "0x46343205", "0x49392806", "0xb1613707", "0x50303208", "0x48332f09",
    "0x4935310a", "0x4d382e0b", "0x5038280c", "0x482f2f0d", "0x4f322b0e",
    "0x4c2e3200", "0x4f352e01", "0x46362e02", "0x49323103", "0x48322c04",
    "0x4b383205", "0x4c382c06", "0xb4543307", "0x4d343108", "0x47352e09",
    "0x48362d0a", "0x4f2f2a0b", "0x4b33290c", "0x4e2e330d", "0x48302d0e",
    "0x50313000", "0x4a382c01", "0x4d352802", "0x49312a03", "0x502f2d04",
    "0x512f2a05", "0x46302d06", "0xb5563d07", "0x4e312a08", "0x4b353009",
    "0x4a332f0a", "0x4e32280b", "0x5037310c", "0x512e2a0d", "0x4e32280e",
    "0x4c392800", "0x472f2a01", "0x4c352a02", "0x512e2f03", "0x48362e04",
    "0x4b332905", "0x46323106", "0xa6613d07", "0x4b333308", "0x50333209",
    "0x4b39320a", "0x5033300b", "0x46322f0c", "0x4d352c0d", "0x4d39320e",
    "0x46352900", "0x46392f01", "0x50342b02", "0x4f392903", "0x4a392a04",
    "0x4a2e2905", "0x512e3206", "0xad613207", "0x50352e08", "0x4e332a09",
    "0x4a2e2c0a", "0x4f392b0b", "0x4731330c", "0x48362f0d", "0x48302c0e",
    "0x46393300", "0x4e2e2b01", "0x49352802", "0x49332d03", "0x4b382d04",
    "0x4d312905", "0x47312e06", "0xaf623c07", "0x4c313208", "0x46352f09",
    "0x4c2f300a", "0x4e312d0b", "0x46342f0c", "0x50382c0d", "0x4e372c0e",
    "0x51362f00", "0x4e323301", "0x51363302", "0x48322803", "0x4e322f04",
    "0x4a312a05", "0x4b322e06", "0xb45f3d07", "0x46303208", "0x48302d09",
    "0x4a372b0a", "0x472f2a0b", "0x4933290c", "0x4b302e0d", "0x4c33290e",
    "0x4c2f3100", "0x48323101", "0x4b362e02", "0x4a382803", "0x4d393304",
    "0x4e2f3205", "0x51383206", "0xa65c3307", "0x4f363008", "0x4f343209",
    "0x51362c0a", "0x47362a0b", "0x48302a0c", "0x5139280d", "0x50352e0e",
    "0x50303200", "0x51382d01", "0x4c342802", "0x4c372e03", "0x49383204",
    "0x46362e05", "0x4c342b06", "0xa9563a07", "0x462f3108", "0x4c382809",
    "0x4f382d0a", "0x4b2e2f0b", "0x4d342a0c", "0x4835280d", "0x46332f0e",
    "0x48392900", "0x4f392a01", "0x51392802", "0x48352e03", "0x4c343204",
    "0x4f382e05", "0x47312c06", "0xaa5b3307", "0x4a322f08", "0x4c2e2d09",
    "0x4a302a0a", "0x5030330b", "0x4d2e2b0c", "0x4b332e0d", "0x4f2f2d0e",
    "0x46362800", "0x492e2801", "0x50332a02", "0x47323303", "0x4c312b04",
    "0x4e352c05", "0x4b332a06", "0xb45c3507", "0x4f372a08", "0x51352809",
    "0x49302f0a", "0x4934310b", "0x4b37310c", "0x51372d0d", "0x4a35320e",
    "0x4b353200", "0x502f3201", "0x47353102", "0x4f2e2903", "0x50373004",
    "0x482e2d05", "0x4a323206", "0xad5d3207", "0x4f352d08", "0x4b383209",
    "0x50322f0a", "0x4d362d0b", "0x4f302d0c", "0x48302d0d", "0x4e2f280e",
    "0x46372c00", "0x4f312d01", "0x47332b02", "0x4f362903", "0x50322d04",
    "0x4e392f05", "0x4f313006", "0xb05a3b07", "0x51332f08", "0x51373309",
    "0x4d2f2e0a", "0x5035330b", "0x46362c0c", "0x4b37320d", "0x4b312d0e",
    "0x47313200", "0x4d2f2801", "0x4c382802", "0x4f312b03", "0x4a303304",
    "0x49303005", "0x4f372c06", "0xaa543107", "0x4e2f3208", "0x4e322a09",
    "0x4f33280a", "0x4a312e0b", "0x4c2f310c", "0x4a38330d", "0x4f33320e",
    "0x4c322c00", "0x4a393201", "0x472e2b02", "0x4e2f2d03", "0x49352804",
    "0x4a392e05", "0x49382806", "0xac563d07", "0x4d372a08", "0x4b392b09",
    "0x4e2f2d0a", "0x482f2b0b", "0x4b372b0c", "0x4f37330d", "0x4932300e",
    "0x4f373100", "0x4f332e01", "0x51343202", "0x4f362f03", "0x51372e04",
    "0x49392a05", "0x4c342e06", "0xa9563607", "0x4d392908", "0x492f2f09",
    "0x4938320a", "0x4b30330b", "0x4833300c", "0x4c2f290d", "0x4b36310e",
    "0x4a302c00", "0x47343001", "0x51332902", "0x4c343103", "0x4f302904",
    "0x46392d05", "0x48313306", "0xb25e3b07", "0x4a2e2b08", "0x51362c09",
    "0x4834300a", "0x4d372f0b", "0x4c39300c", "0x4f392d0d", "0x4b31300e",
    "0x50372c00", "0x48363001", "0x49373102", "0x48352c03", "0x4d302a04",
    "0x4a362905", "0x4f2f2e06", "0xb2583507", "0x47392d08", "0x502e2909",
    "0x5133320a", "0x4639330b", "0x4b30310c", "0x4c33310d", "0x4b2e320e",
    "0x47372900", "0x49332901", "0x47392902", "0x51383303", "0x49333104",
    "0x4c302b05", "0x4f312906", "0xab5d3a07", "0x49392e08", "0x48362d09",
    "0x4c38300a", "0x4f37300b", "0x4637330c", "0x4c2e2f0d", "0x5031330e",
    "0x50342f00", "0x4d363101", "0x4c382902", "0x50382b03", "0x4a342b04",
    "0x482e3205", "0x4d392f06", "0xa7553807", "0x50333308", "0x49353309",
    "0x4632300a", "0x472e2e0b", "0x4a382e0c", "0x51332c0d", "0x48332b0e",
    "0x4a342900", "0x51352e01", "0x46383102", "0x4e373303", "0x48362904",
    "0x47322c05", "0x49303106", "0xaa553d07", "0x512e2f08", "0x4c363309",
    "0x4f372c0a", "0x4f352a0b", "0x4731310c", "0x4e392a0d", "0x5135330e",
    "0x4b332e00", "0x4e363201", "0x4b2e2e02", "0x46383003", "0x4c372a04",
    "0x51312805", "0x51312f06", "0xb1543d07", "0x4c322a08", "0x4e393109",
    "0x5038320a", "0x4f33300b", "0x4632320c", "0x482f2e0d", "0x4f30310e",
    "0x502f2a00", "0x49343001", "0x4e333202", "0x51352f03", "0x46342c04",
    "0x4d333205", "0x4d322a06", "0xa6553907", "0x51382b08", "0x4b372d09",
    "0x4e362f0a", "0x4d372a0b", "0x4c382c0c", "0x48362e0d", "0x4d34330e"
];

function parseSelector(sel) {
    const val = parseInt(sel, 16);
    return {
        selector: sel,
        value: val,
        r: (val >> 24) & 0xFF,
        g: (val >> 16) & 0xFF,
        b: (val >> 8) & 0xFF,
        col: val & 0xFF
    };
}

function generateContract(pixels) {
    // Parse all selectors with their source positions
    const selectorData = ORIGINAL_SELECTORS.map((sel, i) => ({
        ...parseSelector(sel),
        sourceRow: Math.floor(i / 15)
    }));

    // Group by column
    const byColumn = {};
    for (const sd of selectorData) {
        if (!byColumn[sd.col]) byColumn[sd.col] = [];
        byColumn[sd.col].push(sd);
    }

    // Sort each column by selector value and assign render row
    for (const col in byColumn) {
        byColumn[col].sort((a, b) => a.value - b.value);
        byColumn[col].forEach((sd, renderRow) => {
            sd.renderRow = renderRow;
        });
    }

    // Generate Solidity code
    let code = `// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { PUSH4 } from "./PUSH4.sol";
import { PUSH4Core } from "./PUSH4Core.sol";

/**
 * @title PUSH4ProxyTemplate
 * @author Generated by generate-proxy.js
 * @notice Renders a pixel art image (15x25 grid)
 */
contract PUSH4ProxyTemplate {
    PUSH4 public push4;
    PUSH4Core public push4core;

    constructor(address _push4, address _push4core) {
        push4 = PUSH4(_push4);
        push4core = PUSH4Core(_push4core);
    }

    function execute(bytes4 selector) external pure returns (bytes4) {
        uint8 r = uint8(selector[0]);
        uint8 g = uint8(selector[1]);
        uint8 b = uint8(selector[2]);
        uint8 col = uint8(selector[3]);
        
        // Get the render row (y position the renderer will assign)
        uint8 renderRow = getRenderRow(r, g, b, col);
        
        // Get pixel color at (col, renderRow)
        (uint8 pr, uint8 pg, uint8 pb) = getPixel(col, renderRow);
        
        return bytes4(bytes.concat(bytes1(pr), bytes1(pg), bytes1(pb), bytes1(col)));
    }

    function getRenderRow(uint8 r, uint8 g, uint8 b, uint8 col) internal pure returns (uint8) {
        uint24 key = (uint24(r) << 16) | (uint24(g) << 8) | uint24(b);
        
`;

    // Generate lookup for each column
    for (let col = 0; col < 15; col++) {
        code += `        if (col == ${col}) {\n`;
        for (const sd of byColumn[col]) {
            const key = (sd.r << 16) | (sd.g << 8) | sd.b;
            code += `            if (key == 0x${key.toString(16).padStart(6, '0')}) return ${sd.renderRow};\n`;
        }
        code += `        }\n`;
    }

    code += `        return 0;
    }

    function getPixel(uint8 col, uint8 row) internal pure returns (uint8 r, uint8 g, uint8 b) {
        bytes memory data;
        
`;

    // Pack pixel data column by column
    for (let x = 0; x < 15; x++) {
        let colData = '';
        for (let y = 0; y < 25; y++) {
            const pixel = pixels.find(p => p.x === x && p.y === y);
            colData += pixel.r.toString(16).padStart(2, '0');
            colData += pixel.g.toString(16).padStart(2, '0');
            colData += pixel.b.toString(16).padStart(2, '0');
        }
        code += `        if (col == ${x}) data = hex"${colData}";\n`;
    }

    code += `        
        uint256 offset = uint256(row) * 3;
        r = uint8(data[offset]);
        g = uint8(data[offset + 1]);
        b = uint8(data[offset + 2]);
    }
}
`;

    return code;
}

async function main() {
    const args = process.argv.slice(2);
    
    if (args.length < 1) {
        console.log('Usage: node generate-proxy.js <image.png> [output.sol]');
        console.log('');
        console.log('Generates a PUSH4ProxyTemplate contract from a 15x25 PNG image.');
        process.exit(1);
    }

    const imagePath = args[0];
    const outputPath = args[1] || 'PUSH4ProxyTemplate.sol';

    console.log(`Loading image: ${imagePath}`);
    const pixels = await loadImage(imagePath);
    console.log(`Loaded ${pixels.length} pixels`);

    console.log('Generating contract...');
    const contract = generateContract(pixels);

    fs.writeFileSync(outputPath, contract);
    console.log(`Contract written to: ${outputPath}`);
}

main().catch(err => {
    console.error('Error:', err.message);
    process.exit(1);
});

