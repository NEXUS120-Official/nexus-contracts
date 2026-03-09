// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
NEXUS ECONOMIC CONSTITUTION ENGINE
SOV-006

Defines protocol invariants that governance must not violate.
This contract does not control the system directly.
It exposes invariant checks for auditors and governance verification.
*/

interface IVaultManager {
    function collateralRatio() external view returns (uint256);
}

interface INXUSDToken {
    function totalSupply() external view returns (uint256);
}

contract NexusEconomicConstitution {

    address public immutable vaultManager;
    address public immutable nxusdToken;

    uint256 public constant MIN_COLLATERAL_RATIO = 150; // 150%
    uint256 public constant MAX_NXUSD_SUPPLY = 1_000_000_000 ether;

    constructor(address _vaultManager, address _nxusdToken) {
        vaultManager = _vaultManager;
        nxusdToken = _nxusdToken;
    }

    function assertProtocolInvariant() external view {

        uint256 cr = IVaultManager(vaultManager).collateralRatio();
        require(cr >= MIN_COLLATERAL_RATIO, "CONSTITUTION: COLLATERAL_RATIO_BROKEN");

        uint256 supply = INXUSDToken(nxusdToken).totalSupply();
        require(supply <= MAX_NXUSD_SUPPLY, "CONSTITUTION: SUPPLY_CAP_BROKEN");
    }
}
