// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IMURIProtocolCreator is IERC165 {
    function isTokenOwner(address creatorContract, address account, uint256 tokenId) external view returns (bool);
}
