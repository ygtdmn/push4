// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { IMURIProtocol } from "../../src/interface/IMURIProtocol.sol";

/**
 * @title MockMURIProtocol
 * @notice Mock implementation of MURI Protocol for testing
 */
contract MockMURIProtocol is IMURIProtocol {
    mapping(address => mapping(uint256 => string)) private _combinedUris;
    mapping(address => mapping(uint256 => string)) private _rawHtml;
    mapping(address => mapping(uint256 => Artwork)) private _artworks;
    mapping(address => mapping(uint256 => Permissions)) private _permissions;
    string private _defaultHtmlTemplate;
    bool public initializeCalled;

    /// @notice Set the combined URIs for a contract/token
    function setCombinedArtworkUris(address contractAddress, uint256 tokenId, string memory uris) external {
        _combinedUris[contractAddress][tokenId] = uris;
    }

    /// @notice Get combined artwork URIs (artist + collector)
    function getCombinedArtworkUris(address contractAddress, uint256 tokenId) external view returns (string memory) {
        return _combinedUris[contractAddress][tokenId];
    }

    /// @notice Set the raw HTML for a contract/token
    function setRawHTML(address contractAddress, uint256 tokenId, string memory html) external {
        _rawHtml[contractAddress][tokenId] = html;
    }

    /// @notice Get raw HTML for rendering
    function renderRawHTML(address contractAddress, uint256 tokenId) external view returns (string memory) {
        string memory html = _rawHtml[contractAddress][tokenId];
        if (bytes(html).length == 0) {
            return "<html><body>Block: {{BLOCK_INTERVAL}}, Core: {{CORE_ADDRESS}}, Token: {{TOKEN_ID}}</body></html>";
        }
        return html;
    }

    /// @notice Initialize token data
    function initializeTokenData(
        address contractAddress,
        uint256 tokenId,
        InitConfig calldata config,
        bytes[] calldata,
        string[] calldata htmlTemplateChunks
    )
        external
    {
        initializeCalled = true;
        _artworks[contractAddress][tokenId] = config.artwork;
        _permissions[contractAddress][tokenId] = config.permissions;

        // Store combined URIs
        string memory uris = "";
        for (uint256 i = 0; i < config.artwork.artistUris.length; i++) {
            if (i > 0) uris = string.concat(uris, ",");
            uris = string.concat(uris, '"', config.artwork.artistUris[i], '"');
        }
        _combinedUris[contractAddress][tokenId] = uris;

        // Store HTML template
        if (htmlTemplateChunks.length > 0) {
            string memory html = "";
            for (uint256 i = 0; i < htmlTemplateChunks.length; i++) {
                html = string.concat(html, htmlTemplateChunks[i]);
            }
            _rawHtml[contractAddress][tokenId] = html;
        }
    }

    function registerContract(address, address) external override { }

    function isContractOperator(address, address) external pure override returns (bool) {
        return true;
    }

    function updateMetadata(address, uint256, string calldata) external override { }

    function updateHtmlTemplate(address, uint256, string[] calldata, bool) external override { }

    function updateThumbnail(address, uint256, Thumbnail calldata, bytes[] calldata) external override { }

    function revokeArtistPermissions(address, uint256, bool, bool, bool, bool, bool, bool, bool) external override { }

    function revokeAllArtistPermissions(address, uint256) external override { }

    function addArtworkUris(address, uint256, string[] calldata) external override { }

    function removeArtworkUris(address, uint256, uint256[] calldata) external override { }

    function setSelectedUri(address, uint256, uint256) external override { }

    function setSelectedThumbnailUri(address, uint256, uint256) external override { }

    function setDisplayMode(address, uint256, DisplayMode) external override { }

    function setDefaultHtmlTemplate(string[] calldata templateParts, bool) external override {
        string memory html = "";
        for (uint256 i = 0; i < templateParts.length; i++) {
            html = string.concat(html, templateParts[i]);
        }
        _defaultHtmlTemplate = html;
    }

    function getDefaultHtmlTemplate() external view override returns (string memory) {
        return _defaultHtmlTemplate;
    }

    function renderImage(address, uint256) external pure override returns (string memory) {
        return "";
    }

    function renderRawImage(address, uint256) external pure override returns (bytes memory) {
        return "";
    }

    function renderHTML(address, uint256) external pure override returns (string memory) {
        return "";
    }

    function renderMetadata(address, uint256) external pure override returns (string memory) {
        return "";
    }

    function getArtistArtworkUris(
        address contractAddress,
        uint256 tokenId
    )
        external
        view
        override
        returns (string[] memory)
    {
        return _artworks[contractAddress][tokenId].artistUris;
    }

    function getCollectorArtworkUris(address, uint256) external pure override returns (string[] memory) {
        return new string[](0);
    }

    function getThumbnailUris(address, uint256) external pure override returns (string[] memory) {
        return new string[](0);
    }

    function getPermissions(
        address contractAddress,
        uint256 tokenId
    )
        external
        view
        override
        returns (Permissions memory)
    {
        return _permissions[contractAddress][tokenId];
    }

    function getArtwork(address contractAddress, uint256 tokenId) external view override returns (Artwork memory) {
        return _artworks[contractAddress][tokenId];
    }

    function getThumbnailInfo(address, uint256) external pure override returns (ThumbnailKind, uint256) {
        return (ThumbnailKind.OFF_CHAIN, 0);
    }

    function getTokenHtmlTemplate(
        address contractAddress,
        uint256 tokenId
    )
        external
        view
        override
        returns (string memory)
    {
        return _rawHtml[contractAddress][tokenId];
    }
}
