// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { PUSH4 } from "./PUSH4.sol";
import { PUSH4Core } from "./PUSH4Core.sol";

contract PUSH4ProxyTemplate {
    PUSH4 public push4;
    PUSH4Core public push4core;

    constructor(address _push4, address _push4core) {
        push4 = PUSH4(_push4);
        push4core = PUSH4Core(_push4core);
    }

    function execute(bytes4 selector) external pure returns (bytes4) {
        // Extract individual bytes
        // Format: selector = 0xRRGGBBII where R=red, G=green, B=blue, I=index
        uint8 r = uint8(selector[0]);
        uint8 g = uint8(selector[1]);
        uint8 b = uint8(selector[2]);
        uint8 index = uint8(selector[3]);

        // Calculate luminance using standard weights (0.299*R + 0.587*G + 0.114*B)
        // Using integer arithmetic: (299*R + 587*G + 114*B) / 1000
        // Use uint32 to avoid overflow (max value: 255*299 + 255*587 + 255*114 = 255000)
        uint16 luminance = uint16((uint32(r) * 299 + uint32(g) * 587 + uint32(b) * 114) / 1000);

        // Only transform dark colors (luminance < 100), leave light colors unchanged
        if (luminance >= 100) {
            return selector;
        }

        // Transform dark colors to off-black (0-15 range) with pseudorandom variation
        // Combine index with color components to ensure unique values per pixel
        uint8 pseudoRandom = uint8((uint16(index) * 7 + uint16(r) + uint16(g) + uint16(b)) % 16);

        // Reconstruct bytes4 with off-black color and preserve index
        return bytes4(bytes.concat(bytes1(pseudoRandom), bytes1(pseudoRandom), bytes1(pseudoRandom), bytes1(index)));
    }
}
