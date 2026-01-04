// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

library PUSH4Lib {
    function getRenderRow(bytes4 selector, uint8 col) internal pure returns (uint8) {
        if (col == 0) {
            if (selector == 0x46352900) return 0;
            if (selector == 0x46362800) return 1;
            if (selector == 0x46372c00) return 2;
            if (selector == 0x46393300) return 3;
            if (selector == 0x47313200) return 4;
            if (selector == 0x47372900) return 5;
            if (selector == 0x48392900) return 6;
            if (selector == 0x4a302c00) return 7;
            if (selector == 0x4a342900) return 8;
            if (selector == 0x4b332e00) return 9;
            if (selector == 0x4b353200) return 10;
            if (selector == 0x4c2e3200) return 11;
            if (selector == 0x4c2f3100) return 12;
            if (selector == 0x4c322c00) return 13;
            if (selector == 0x4c392800) return 14;
            if (selector == 0x4f302900) return 15;
            if (selector == 0x4f362900) return 16;
            if (selector == 0x4f373100) return 17;
            if (selector == 0x502f2a00) return 18;
            if (selector == 0x50303200) return 19;
            if (selector == 0x50313000) return 20;
            if (selector == 0x50342f00) return 21;
            if (selector == 0x50372c00) return 22;
            if (selector == 0x51352d00) return 23;
            if (selector == 0x51362f00) return 24;
        }
        if (col == 1) {
            if (selector == 0x46392f01) return 0;
            if (selector == 0x472f2a01) return 1;
            if (selector == 0x47343001) return 2;
            if (selector == 0x482f2f01) return 3;
            if (selector == 0x48323101) return 4;
            if (selector == 0x48363001) return 5;
            if (selector == 0x492e2801) return 6;
            if (selector == 0x49332901) return 7;
            if (selector == 0x49343001) return 8;
            if (selector == 0x4a382c01) return 9;
            if (selector == 0x4a393201) return 10;
            if (selector == 0x4c352b01) return 11;
            if (selector == 0x4d2f2801) return 12;
            if (selector == 0x4d363101) return 13;
            if (selector == 0x4e2e2b01) return 14;
            if (selector == 0x4e323301) return 15;
            if (selector == 0x4e363201) return 16;
            if (selector == 0x4f312d01) return 17;
            if (selector == 0x4f332e01) return 18;
            if (selector == 0x4f352e01) return 19;
            if (selector == 0x4f392a01) return 20;
            if (selector == 0x502f3201) return 21;
            if (selector == 0x51352e01) return 22;
            if (selector == 0x51363301) return 23;
            if (selector == 0x51382d01) return 24;
        }
        if (col == 2) {
            if (selector == 0x46322d02) return 0;
            if (selector == 0x46362e02) return 1;
            if (selector == 0x46383102) return 2;
            if (selector == 0x472e2b02) return 3;
            if (selector == 0x47312f02) return 4;
            if (selector == 0x47332b02) return 5;
            if (selector == 0x47353102) return 6;
            if (selector == 0x47392902) return 7;
            if (selector == 0x49352802) return 8;
            if (selector == 0x49373102) return 9;
            if (selector == 0x4b2e2e02) return 10;
            if (selector == 0x4b362e02) return 11;
            if (selector == 0x4c342802) return 12;
            if (selector == 0x4c352a02) return 13;
            if (selector == 0x4c382802) return 14;
            if (selector == 0x4c382902) return 15;
            if (selector == 0x4d352802) return 16;
            if (selector == 0x4e333202) return 17;
            if (selector == 0x50332a02) return 18;
            if (selector == 0x50342b02) return 19;
            if (selector == 0x51332902) return 20;
            if (selector == 0x51343202) return 21;
            if (selector == 0x51363302) return 22;
            if (selector == 0x51392802) return 23;
            if (selector == 0x51392a02) return 24;
        }
        if (col == 3) {
            if (selector == 0x46383003) return 0;
            if (selector == 0x47323303) return 1;
            if (selector == 0x48302903) return 2;
            if (selector == 0x48322803) return 3;
            if (selector == 0x48332f03) return 4;
            if (selector == 0x48352c03) return 5;
            if (selector == 0x48352e03) return 6;
            if (selector == 0x49312a03) return 7;
            if (selector == 0x49323103) return 8;
            if (selector == 0x49332d03) return 9;
            if (selector == 0x4a352803) return 10;
            if (selector == 0x4a382803) return 11;
            if (selector == 0x4c343103) return 12;
            if (selector == 0x4c372e03) return 13;
            if (selector == 0x4e2f2d03) return 14;
            if (selector == 0x4e373303) return 15;
            if (selector == 0x4f2e2903) return 16;
            if (selector == 0x4f312b03) return 17;
            if (selector == 0x4f362903) return 18;
            if (selector == 0x4f362f03) return 19;
            if (selector == 0x4f392903) return 20;
            if (selector == 0x50382b03) return 21;
            if (selector == 0x512e2f03) return 22;
            if (selector == 0x51352f03) return 23;
            if (selector == 0x51383303) return 24;
        }
        if (col == 4) {
            if (selector == 0x462e3104) return 0;
            if (selector == 0x46342c04) return 1;
            if (selector == 0x48312b04) return 2;
            if (selector == 0x48322c04) return 3;
            if (selector == 0x48362904) return 4;
            if (selector == 0x48362e04) return 5;
            if (selector == 0x49333104) return 6;
            if (selector == 0x49352804) return 7;
            if (selector == 0x49383204) return 8;
            if (selector == 0x4a303304) return 9;
            if (selector == 0x4a342b04) return 10;
            if (selector == 0x4a392a04) return 11;
            if (selector == 0x4b382d04) return 12;
            if (selector == 0x4c312b04) return 13;
            if (selector == 0x4c343204) return 14;
            if (selector == 0x4c372a04) return 15;
            if (selector == 0x4d302a04) return 16;
            if (selector == 0x4d393304) return 17;
            if (selector == 0x4e2f3304) return 18;
            if (selector == 0x4e322f04) return 19;
            if (selector == 0x4f302904) return 20;
            if (selector == 0x502f2d04) return 21;
            if (selector == 0x50322d04) return 22;
            if (selector == 0x50373004) return 23;
            if (selector == 0x51372e04) return 24;
        }
        if (col == 5) {
            if (selector == 0x46343205) return 0;
            if (selector == 0x46362e05) return 1;
            if (selector == 0x46392d05) return 2;
            if (selector == 0x47322c05) return 3;
            if (selector == 0x482e2d05) return 4;
            if (selector == 0x482e3205) return 5;
            if (selector == 0x49303005) return 6;
            if (selector == 0x49392a05) return 7;
            if (selector == 0x4a2e2905) return 8;
            if (selector == 0x4a312a05) return 9;
            if (selector == 0x4a362905) return 10;
            if (selector == 0x4a392e05) return 11;
            if (selector == 0x4b332905) return 12;
            if (selector == 0x4b383205) return 13;
            if (selector == 0x4c302b05) return 14;
            if (selector == 0x4d312905) return 15;
            if (selector == 0x4d333205) return 16;
            if (selector == 0x4e2f3205) return 17;
            if (selector == 0x4e303305) return 18;
            if (selector == 0x4e332905) return 19;
            if (selector == 0x4e352c05) return 20;
            if (selector == 0x4e392f05) return 21;
            if (selector == 0x4f382e05) return 22;
            if (selector == 0x512f2a05) return 23;
            if (selector == 0x51312805) return 24;
        }
        if (col == 6) {
            if (selector == 0x46302d06) return 0;
            if (selector == 0x46323106) return 1;
            if (selector == 0x47312c06) return 2;
            if (selector == 0x47312e06) return 3;
            if (selector == 0x48313306) return 4;
            if (selector == 0x49303106) return 5;
            if (selector == 0x49382806) return 6;
            if (selector == 0x49392806) return 7;
            if (selector == 0x4a323206) return 8;
            if (selector == 0x4b322e06) return 9;
            if (selector == 0x4b332a06) return 10;
            if (selector == 0x4b343006) return 11;
            if (selector == 0x4c342b06) return 12;
            if (selector == 0x4c342e06) return 13;
            if (selector == 0x4c382c06) return 14;
            if (selector == 0x4d322a06) return 15;
            if (selector == 0x4d392f06) return 16;
            if (selector == 0x4f2f2e06) return 17;
            if (selector == 0x4f312906) return 18;
            if (selector == 0x4f313006) return 19;
            if (selector == 0x4f372c06) return 20;
            if (selector == 0x50362b06) return 21;
            if (selector == 0x512e3206) return 22;
            if (selector == 0x51312f06) return 23;
            if (selector == 0x51383206) return 24;
        }
        if (col == 7) {
            if (selector == 0xa6553907) return 0;
            if (selector == 0xa65c3307) return 1;
            if (selector == 0xa6613d07) return 2;
            if (selector == 0xa7553807) return 3;
            if (selector == 0xa9563607) return 4;
            if (selector == 0xa9563a07) return 5;
            if (selector == 0xaa543107) return 6;
            if (selector == 0xaa553d07) return 7;
            if (selector == 0xaa5b3307) return 8;
            if (selector == 0xab5d3a07) return 9;
            if (selector == 0xac563d07) return 10;
            if (selector == 0xad5d3207) return 11;
            if (selector == 0xad613207) return 12;
            if (selector == 0xaf623c07) return 13;
            if (selector == 0xb05a3b07) return 14;
            if (selector == 0xb1543d07) return 15;
            if (selector == 0xb1613707) return 16;
            if (selector == 0xb2583507) return 17;
            if (selector == 0xb25e3b07) return 18;
            if (selector == 0xb35c3907) return 19;
            if (selector == 0xb4543307) return 20;
            if (selector == 0xb45c3507) return 21;
            if (selector == 0xb45f3d07) return 22;
            if (selector == 0xb5553c07) return 23;
            if (selector == 0xb5563d07) return 24;
        }
        if (col == 8) {
            if (selector == 0x462f3108) return 0;
            if (selector == 0x46303208) return 1;
            if (selector == 0x46323108) return 2;
            if (selector == 0x47392d08) return 3;
            if (selector == 0x49392e08) return 4;
            if (selector == 0x4a2e2b08) return 5;
            if (selector == 0x4a322f08) return 6;
            if (selector == 0x4b333308) return 7;
            if (selector == 0x4c313208) return 8;
            if (selector == 0x4c322a08) return 9;
            if (selector == 0x4d343108) return 10;
            if (selector == 0x4d372a08) return 11;
            if (selector == 0x4d392908) return 12;
            if (selector == 0x4d392c08) return 13;
            if (selector == 0x4e2f3208) return 14;
            if (selector == 0x4e312a08) return 15;
            if (selector == 0x4f352d08) return 16;
            if (selector == 0x4f363008) return 17;
            if (selector == 0x4f372a08) return 18;
            if (selector == 0x50303208) return 19;
            if (selector == 0x50333308) return 20;
            if (selector == 0x50352e08) return 21;
            if (selector == 0x512e2f08) return 22;
            if (selector == 0x51332f08) return 23;
            if (selector == 0x51382b08) return 24;
        }
        if (col == 9) {
            if (selector == 0x46352f09) return 0;
            if (selector == 0x47352e09) return 1;
            if (selector == 0x48302d09) return 2;
            if (selector == 0x48332f09) return 3;
            if (selector == 0x48362d09) return 4;
            if (selector == 0x492f2f09) return 5;
            if (selector == 0x49353309) return 6;
            if (selector == 0x4b353009) return 7;
            if (selector == 0x4b372d09) return 8;
            if (selector == 0x4b383209) return 9;
            if (selector == 0x4b392b09) return 10;
            if (selector == 0x4c2e2d09) return 11;
            if (selector == 0x4c363309) return 12;
            if (selector == 0x4c382809) return 13;
            if (selector == 0x4e322a09) return 14;
            if (selector == 0x4e332a09) return 15;
            if (selector == 0x4e393109) return 16;
            if (selector == 0x4f323209) return 17;
            if (selector == 0x4f343209) return 18;
            if (selector == 0x502e2909) return 19;
            if (selector == 0x50333209) return 20;
            if (selector == 0x51333209) return 21;
            if (selector == 0x51352809) return 22;
            if (selector == 0x51362c09) return 23;
            if (selector == 0x51373309) return 24;
        }
        if (col == 10) {
            if (selector == 0x4632300a) return 0;
            if (selector == 0x48322d0a) return 1;
            if (selector == 0x4834300a) return 2;
            if (selector == 0x48362d0a) return 3;
            if (selector == 0x49302f0a) return 4;
            if (selector == 0x4935310a) return 5;
            if (selector == 0x4938320a) return 6;
            if (selector == 0x4a2e2c0a) return 7;
            if (selector == 0x4a302a0a) return 8;
            if (selector == 0x4a332f0a) return 9;
            if (selector == 0x4a372b0a) return 10;
            if (selector == 0x4b39320a) return 11;
            if (selector == 0x4c2f300a) return 12;
            if (selector == 0x4c302c0a) return 13;
            if (selector == 0x4c38300a) return 14;
            if (selector == 0x4d2f2e0a) return 15;
            if (selector == 0x4e2f2d0a) return 16;
            if (selector == 0x4e362f0a) return 17;
            if (selector == 0x4f33280a) return 18;
            if (selector == 0x4f372c0a) return 19;
            if (selector == 0x4f382d0a) return 20;
            if (selector == 0x50322f0a) return 21;
            if (selector == 0x5038320a) return 22;
            if (selector == 0x5133320a) return 23;
            if (selector == 0x51362c0a) return 24;
        }
        if (col == 11) {
            if (selector == 0x46382e0b) return 0;
            if (selector == 0x4639330b) return 1;
            if (selector == 0x472e2e0b) return 2;
            if (selector == 0x472f2a0b) return 3;
            if (selector == 0x47362a0b) return 4;
            if (selector == 0x482f2b0b) return 5;
            if (selector == 0x4934310b) return 6;
            if (selector == 0x4a312e0b) return 7;
            if (selector == 0x4b2e2f0b) return 8;
            if (selector == 0x4b30330b) return 9;
            if (selector == 0x4d362d0b) return 10;
            if (selector == 0x4d372a0b) return 11;
            if (selector == 0x4d372f0b) return 12;
            if (selector == 0x4d382e0b) return 13;
            if (selector == 0x4e312d0b) return 14;
            if (selector == 0x4e32280b) return 15;
            if (selector == 0x4e322d0b) return 16;
            if (selector == 0x4f2f2a0b) return 17;
            if (selector == 0x4f33300b) return 18;
            if (selector == 0x4f352a0b) return 19;
            if (selector == 0x4f37300b) return 20;
            if (selector == 0x4f392b0b) return 21;
            if (selector == 0x5030330b) return 22;
            if (selector == 0x5033300b) return 23;
            if (selector == 0x5035330b) return 24;
        }
        if (col == 12) {
            if (selector == 0x46322f0c) return 0;
            if (selector == 0x4632320c) return 1;
            if (selector == 0x46342f0c) return 2;
            if (selector == 0x46362c0c) return 3;
            if (selector == 0x4637330c) return 4;
            if (selector == 0x4731310c) return 5;
            if (selector == 0x4731330c) return 6;
            if (selector == 0x48302a0c) return 7;
            if (selector == 0x4831280c) return 8;
            if (selector == 0x4833300c) return 9;
            if (selector == 0x4933290c) return 10;
            if (selector == 0x4a382e0c) return 11;
            if (selector == 0x4b30310c) return 12;
            if (selector == 0x4b33290c) return 13;
            if (selector == 0x4b372b0c) return 14;
            if (selector == 0x4b37310c) return 15;
            if (selector == 0x4c2f2b0c) return 16;
            if (selector == 0x4c2f310c) return 17;
            if (selector == 0x4c382c0c) return 18;
            if (selector == 0x4c39300c) return 19;
            if (selector == 0x4d2e2b0c) return 20;
            if (selector == 0x4d342a0c) return 21;
            if (selector == 0x4f302d0c) return 22;
            if (selector == 0x5037310c) return 23;
            if (selector == 0x5038280c) return 24;
        }
        if (col == 13) {
            if (selector == 0x482f2e0d) return 0;
            if (selector == 0x482f2f0d) return 1;
            if (selector == 0x48302d0d) return 2;
            if (selector == 0x4835280d) return 3;
            if (selector == 0x48362e0d) return 4;
            if (selector == 0x48362f0d) return 5;
            if (selector == 0x4839310d) return 6;
            if (selector == 0x4a38330d) return 7;
            if (selector == 0x4b302e0d) return 8;
            if (selector == 0x4b332e0d) return 9;
            if (selector == 0x4b37320d) return 10;
            if (selector == 0x4c2e2f0d) return 11;
            if (selector == 0x4c2f290d) return 12;
            if (selector == 0x4c33310d) return 13;
            if (selector == 0x4d352c0d) return 14;
            if (selector == 0x4e2e330d) return 15;
            if (selector == 0x4e392a0d) return 16;
            if (selector == 0x4f37330d) return 17;
            if (selector == 0x4f392d0d) return 18;
            if (selector == 0x50382c0d) return 19;
            if (selector == 0x512e2a0d) return 20;
            if (selector == 0x51332c0d) return 21;
            if (selector == 0x5135330d) return 22;
            if (selector == 0x51372d0d) return 23;
            if (selector == 0x5139280d) return 24;
        }
        if (col == 14) {
            if (selector == 0x46332f0e) return 0;
            if (selector == 0x472e310e) return 1;
            if (selector == 0x48302c0e) return 2;
            if (selector == 0x48302d0e) return 3;
            if (selector == 0x4831330e) return 4;
            if (selector == 0x48332b0e) return 5;
            if (selector == 0x4932300e) return 6;
            if (selector == 0x4a35320e) return 7;
            if (selector == 0x4b2e320e) return 8;
            if (selector == 0x4b312d0e) return 9;
            if (selector == 0x4b31300e) return 10;
            if (selector == 0x4b36310e) return 11;
            if (selector == 0x4c33290e) return 12;
            if (selector == 0x4d34330e) return 13;
            if (selector == 0x4d39320e) return 14;
            if (selector == 0x4e2f280e) return 15;
            if (selector == 0x4e32280e) return 16;
            if (selector == 0x4e372c0e) return 17;
            if (selector == 0x4f2f2d0e) return 18;
            if (selector == 0x4f30310e) return 19;
            if (selector == 0x4f322b0e) return 20;
            if (selector == 0x4f33320e) return 21;
            if (selector == 0x5031330e) return 22;
            if (selector == 0x50352e0e) return 23;
            if (selector == 0x5135330e) return 24;
        }
        return 0;
    }

    function getPixel(uint8 col, uint8 row) internal pure returns (uint8 r, uint8 g, uint8 b) {
        bytes memory data;
        if (col == 0) {
            data =
                hex"e83036eb952cefa435534e313b3b3b151208f9a821577d78ad9e74bfa576ba9c6dd3c89fdad0a7d6cca4ddd4abe4cfa1b59b62905a43a14c2f6f4b27131110131110131110131110131110";
        }
        if (col == 1) {
            data =
                hex"f92f28fd8c2cf08c26a97e2e171717050507552919552919552919552919552919552919552919552919552919552919efc98dedefc1e6e8bddec9917d5f3513111013111058361f77553e";
        }
        if (col == 2) {
            data =
                hex"f12e2def2f24f4932aa77d26332721513315552919d9bb7cdec081e9cb95e2c38cf7f6cae8cc8fe0c581a28069552919896a36f7f6cae6e8bdeff0c2f7f4c6ece8c4fffdcfe1cb8bedf2c7";
        }
        if (col == 3) {
            data =
                hex"ef3432eb2f2df48b368f623d552919e2c381e1bd88d5cc9ddab882f1eec3552919ddbf87f3efc1e5e6b8e4e0b8e5dcb35529195529195529198b6f54a584588e6f526a59426a5947564432";
        }
        if (col == 4) {
            data =
                hex"f2302dee332f552919552919c6a97ef3e3b0e3c487dfe1b6d8c18ef1eec3f1eec3e0c08bf7f6cae3d39fdfe0b4cdc59af2f2c3c8c09b674c3d552919383021332e2b13111011100d131110";
        }
        if (col == 5) {
            data =
                hex"f72c2ff12626552919e0ca9af7f6caeccf8de8c886ece9beedeabfe4c489eaca90e5c68bf7f6caf3ecc4e8e0bafbf9cefdf5cef6f3c2e9e7b6dcc58a8364304d2e0f01010403010214171b";
        }
        if (col == 6) {
            data =
                hex"f92828523317552919e2d1a1f7f6caeac788f7f6caedeabff7f6cafdfbcefbf7ccf7f2c7fbfcc9552919edd3a2ffffd65529195a3320552919e0c480f6f8c3f2f0bb4d2912966d387b5537";
        }
        if (col == 7) {
            data =
                hex"eb312f94703c552919dbc18ed7bd89f7f6caf3f3c7e9e6bbebe9bef7f6caf7f6caf7f6caf7f6caaba16ae8e8b4916538e4c68bdebf84dabd855d3926e2c386ddc58cfcf4c65529198e7156";
        }
        if (col == 8) {
            data =
                hex"fb2e2a916e36552919ddc08fd8c28af7f6cafcfdcdedebbbeeecbcfdf4c7f7f6caf6f1c3fafbcef7f6cae7e9c1f7f6ca9a6539633c2b5a332adabb84e4c68ce1c486fefaca5529195a3b2a";
        }
        if (col == 9) {
            data =
                hex"ec2c368e743c552919dfc89bf7f6caedf1c1f0ecc6e2dfb6e3e0b7e1c58fe8c88cedebbdede9bce2dcb6e0d7acede4b7eef0c2f7f6cadbd9afd4c390dfcd9de4e3b9552919946c48c3a87d";
        }
        if (col == 10) {
            data =
                hex"ed3b2caf7838552919dfcc99f7f6caf7f6caedefcbdfdfb2d6bc88f1eec3552919e8c88cece5badbcd9fcdc59acdc59af6f4c9dbc998dbc094e4dba5e5dfb0552919131110131110131110";
        }
        if (col == 11) {
            data =
                hex"fb3323f99222976931552919e2d3a4fafac7fcfcceedebbbf0eebef1eec3f1eec3e6c589fbf9c7efeec1ececbdfcfcc55529195529195529195529195529195c362f060204000304131110";
        }
        if (col == 12) {
            data =
                hex"f83221f3af2606030b976d34552919fefed0f8f8cceeebc0f0edc2e7d09af9f4c7f7f2c4fcfad2f0f0c2eaebbde3c991552919d5b175e7e9bceff2c2f6e9b7dcbd868e6d37906c3c3e2f24";
        }
        if (col == 13) {
            data =
                hex"f58e2af5a93a0f0f121e1f1b3b3931552919552919552919552919552919552919552919552919552919552919552919e7ddaad9cf98b69e79b28e6193725199754ab798598f6c50a68654";
        }
        if (col == 14) {
            data =
                hex"f18f2ef4a8391010131f1f1c3a505bc9a975552919552919cdc59acdc59acdc59ac8a879d7cb9ecdc59ad4c9a8efedc2e6cf978c724e6d523769492e4e3729312c26131110131110131110";
        }

        uint256 offset = uint256(row) * 3;
        r = uint8(data[offset]);
        g = uint8(data[offset + 1]);
        b = uint8(data[offset + 2]);
    }
}
