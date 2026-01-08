// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { IPUSH4OrchestratorProxy } from "../../src/interface/IPUSH4OrchestratorProxy.sol";

/**
 * @title MockOrchestratorProxy
 * @notice Mock implementation of IPUSH4OrchestratorProxy for testing
 */
contract MockOrchestratorProxy is IPUSH4OrchestratorProxy {
    address private _owner;
    mapping(address => bool) private _creators;

    string private _title;
    string private _description;
    Creator private _creator;

    constructor(address orchestratorOwner) {
        _owner = orchestratorOwner;
        _title = "Mock Orchestrator";
        _description = "Mock orchestrator for testing";
        _creator = Creator({ name: "Test Creator", wallet: orchestratorOwner });
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function isCreator(address account) external view returns (bool) {
        return _creators[account];
    }

    function setOwner(address newOwner) external {
        _owner = newOwner;
    }

    function addCreator(address account) external {
        _creators[account] = true;
    }

    function removeCreator(address account) external {
        _creators[account] = false;
    }

    function execute(bytes4 selector) external pure returns (bytes4) {
        return selector;
    }

    function title() external view returns (string memory) {
        return _title;
    }

    function description() external view returns (string memory) {
        return _description;
    }

    function creator() external view returns (Creator memory) {
        return _creator;
    }
}

