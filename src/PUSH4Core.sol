// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { ERC721 } from "solady/tokens/ERC721.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IPUSH4Renderer } from "./interface/IPUSH4Renderer.sol";
import { Sculpture } from "./interface/Sculpture.sol";
import { LibString } from "solady/utils/LibString.sol";
import { IPUSH4Core } from "./interface/IPUSH4Core.sol";

/**
 * @title PUSH4Core
 * @author Yigit Duman
 */
contract PUSH4Core is Sculpture, ERC721, Ownable, IPUSH4Core {
    uint256 public constant TOKEN_ID = 0;

    address public push4;
    IPUSH4Renderer public renderer;

    uint256 public deploymentTimestamp;

    Mode public mode;
    address public proxy;

    constructor(address _push4, address _owner) Ownable(_owner) {
        push4 = _push4;
        deploymentTimestamp = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERC721
    //////////////////////////////////////////////////////////////*/

    function name() public view virtual override returns (string memory) {
        return "PUSH4";
    }

    function symbol() public view virtual override returns (string memory) {
        return "PUSH4";
    }

    function _isMinted() internal view returns (bool) {
        return _ownerOf(TOKEN_ID) != address(0);
    }

    function tokenURI(uint256) public view virtual override returns (string memory) {
        require(_isMinted(), NotMinted());
        return renderer.getMetadataDataUri();
    }

    function totalSupply() external view returns (uint256) {
        if (!_isMinted()) {
            return 0;
        }
        return 1;
    }

    function mint(address to) external onlyOwner {
        if (_isMinted()) {
            revert AlreadyMinted();
        }
        _mint(to, TOKEN_ID);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId) || interfaceId == 0x49064906; // ERC4906
    }

    /*//////////////////////////////////////////////////////////////
                           CONTRACT OWNER ONLY
    //////////////////////////////////////////////////////////////*/

    modifier onlyInGracePeriod() {
        _onlyInGracePeriod();
        _;
    }

    function _onlyInGracePeriod() internal view {
        require(inGracePeriod(), NotInGracePeriod());
    }

    // Allow 60 days after deployment to configure the renderer and push4 contract addresses
    function inGracePeriod() public view returns (bool) {
        return block.timestamp <= deploymentTimestamp + 60 days;
    }

    function setRenderer(IPUSH4Renderer _renderer) external onlyOwner onlyInGracePeriod {
        renderer = _renderer;
        emit MetadataUpdate(TOKEN_ID);
    }

    function setPush4(address _push4) external onlyOwner onlyInGracePeriod {
        push4 = _push4;
        emit MetadataUpdate(TOKEN_ID);
    }

    /*//////////////////////////////////////////////////////////////
                            TOKEN OWNER ONLY
    //////////////////////////////////////////////////////////////*/

    modifier onlyTokenOwner() {
        _onlyTokenOwner();
        _;
    }

    function _onlyTokenOwner() internal view {
        require(msg.sender == _ownerOf(TOKEN_ID), NotTokenOwner());
    }

    function setMode(Mode _mode) external onlyTokenOwner {
        mode = _mode;
        emit MetadataUpdate(TOKEN_ID);
        emit ModeSet(_mode);
    }

    function setProxy(address _proxy) external onlyTokenOwner {
        proxy = _proxy;
        emit MetadataUpdate(TOKEN_ID);
        emit ProxySet(_proxy);
    }

    /*//////////////////////////////////////////////////////////////
                                SCULPTURE
    //////////////////////////////////////////////////////////////*/

    function title() external pure override returns (string memory) {
        return "PUSH4";
    }

    function authors() external view override returns (string[] memory _authors) {
        bool hasProxy = mode == Mode.Executed && proxy != address(0);
        _authors = new string[](hasProxy ? 2 : 1);
        _authors[0] = "Yigit Duman";
        if (hasProxy) {
            _authors[1] = LibString.toHexStringChecksummed(_ownerOf(TOKEN_ID));
        }
    }

    function addresses() external view override returns (address[] memory _addresses) {
        bool hasProxy = mode == Mode.Executed && proxy != address(0);
        _addresses = new address[](hasProxy ? 2 : 1);
        _addresses[0] = push4;
        if (hasProxy) {
            _addresses[1] = proxy;
        }
    }

    function urls() external view override returns (string[] memory _urls) {
        _urls = new string[](1);
        _urls[0] = renderer.getSvgDataUri();
    }

    function text() external view override returns (string memory _text) {
        if (mode == Mode.Carved || proxy == address(0)) {
            _text = "Representing as Carved";
        } else {
            _text = "Representing as Executed";
        }
    }
}
