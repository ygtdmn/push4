// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { IMURIProtocolCreator } from "./interface/IMURIProtocolCreator.sol";
import { IMURIProtocol } from "./interface/IMURIProtocol.sol";
import { IPUSH4OrchestratorProxy } from "./interface/IPUSH4OrchestratorProxy.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { PUSH4RendererV2 } from "./PUSH4RendererV2.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title PUSH4MURIOperator
 * @author Yigit Duman
 */
contract PUSH4MURIOperator is IMURIProtocolCreator, Ownable {
    IPUSH4OrchestratorProxy public orchestrator;
    PUSH4RendererV2 public renderer;
    IMURIProtocol public muriProtocol;

    event OrchestratorUpdated(address indexed orchestrator);
    event RendererUpdated(address indexed renderer);
    event MURIProtocolUpdated(address indexed muriProtocol);

    constructor(
        IPUSH4OrchestratorProxy _orchestrator,
        PUSH4RendererV2 _renderer,
        IMURIProtocol _muriProtocol,
        address _owner
    )
        Ownable(_owner)
    {
        orchestrator = _orchestrator;
        renderer = _renderer;
        muriProtocol = _muriProtocol;
    }

    function initializeTokenData(
        address contractAddress,
        uint256 tokenId,
        IMURIProtocol.InitConfig calldata config,
        bytes[] calldata thumbnailChunks,
        string[] calldata htmlTemplateChunks
    )
        external
        onlyOwner
    {
        muriProtocol.initializeTokenData(contractAddress, tokenId, config, thumbnailChunks, htmlTemplateChunks);
    }

    function isTokenOwner(address creatorContract, address account, uint256 tokenId) external view returns (bool) {
        if (address(orchestrator) != address(0)) {
            if (account == orchestrator.owner()) {
                return true;
            }

            if (orchestrator.isCreator(account)) {
                return true;
            }
        }

        try IERC721(creatorContract).ownerOf(tokenId) returns (address tokenOwner) {
            if (tokenOwner == account) {
                return true;
            }
        } catch { }

        return false;
    }

    function setOrchestrator(IPUSH4OrchestratorProxy _orchestrator) external onlyOwner {
        orchestrator = _orchestrator;
        emit OrchestratorUpdated(address(_orchestrator));
    }

    function setRenderer(PUSH4RendererV2 _renderer) external onlyOwner {
        renderer = _renderer;
        emit RendererUpdated(address(_renderer));
    }

    function setMURIProtocol(address _muriProtocol) external onlyOwner {
        muriProtocol = IMURIProtocol(_muriProtocol);
        emit MURIProtocolUpdated(_muriProtocol);
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IMURIProtocolCreator).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
