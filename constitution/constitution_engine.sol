// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 * ============================================================================
 * AUDIT SCOPE: EXCLUDED — NOT DEPLOYED
 * ============================================================================
 *
 * This contract has NOT been deployed to any network and is NOT part of the
 * live protocol. It is a reference document expressing invariant intent.
 *
 * INTERFACE MISMATCH (blocking deployment):
 * NexusEconomicConstitution.assertProtocolInvariant() calls
 * IVaultManager.collateralRatio() — this function does not exist on the
 * deployed VaultManager contract. VaultManager exposes per-user state as
 * collateralOf[address] and debtOf[address] mappings; there is no
 * protocol-level collateralRatio() view function.
 *
 * INVARIANT STATUS IN LIVE SYSTEM:
 * - MIN_COLLATERAL_RATIO (150%): enforced per-position by VaultManager._isSafe()
 *   at every mint and withdraw operation. See invariant I-01, I-02 in audit doc.
 * - MAX_NXUSD_SUPPLY: NOT enforced on-chain. Known gap, see L-05 in audit doc.
 *
 * DO NOT AUDIT THIS FILE. Exclude from all automated tools and scope definitions.
 *
 * NEXUS ECONOMIC CONSTITUTION ENGINE — SOV-006
 * Defines protocol invariants that governance must not violate.
 * ============================================================================
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
