// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

interface IRealAbstraction {
  struct line {
    address creator;
    uint256 field1;
    uint256 field2;
    uint256 field3;
    uint256 field4;
  }

  function lastPart() external view returns (uint256);

  function linePart(
    uint256 index
  ) external view returns (address creator, uint256 field1, uint256 field2, uint256 field3, uint256 field4);
}
