// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { IPUSH4Renderer } from "./IPUSH4Renderer.sol";

interface IPUSH4Core {
    // Enums
    enum Mode {
        Carved,
        Executed
    }

    // Errors
    error AlreadyMinted();
    error NotMinted();
    error NotTokenOwner();
    error NotInGracePeriod();

    // Events
    event MetadataUpdate(uint256 _tokenId);
    event ModeSet(Mode _mode);
    event ProxySet(address _proxy);

    // State variable getters
    function TOKEN_ID() external view returns (uint256);
    function push4() external view returns (address);
    function deploymentTimestamp() external view returns (uint256);
    function renderer() external view returns (IPUSH4Renderer);
    function mode() external view returns (Mode);
    function proxy() external view returns (address);
    function inGracePeriod() external view returns (bool);

    // Minting
    function mint(address to) external;

    // Contract owner only functions
    function setRenderer(IPUSH4Renderer _renderer) external;
    function setPush4(address _push4) external;

    // Token owner only functions
    function setMode(Mode _mode) external;
    function setProxy(address _proxy) external;
}
