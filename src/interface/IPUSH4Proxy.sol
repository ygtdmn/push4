// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

interface IPUSH4Proxy {
    struct Creator {
        string name;
        address wallet;
    }

    function execute(bytes4 selector) external view returns (bytes4);
    function title() external view returns (string memory);
    function description() external view returns (string memory);
    function creator() external view returns (Creator memory);
}
