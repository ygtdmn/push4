// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

interface ICryptopunksData {
    function punkImage(uint16 index) external view returns (bytes memory);

    function punkImageSvg(uint16 index) external view returns (string memory);

    function punkAttributes(uint16 index) external view returns (string memory);
}
