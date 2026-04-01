// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

/**
 * @title NXUSDToken
 * @notice NXUSD is the USD-pegged stable asset of the NEXUS protocol.
 *         Minimal ERC20 with role-gated mint/burn and admin helpers.
 *
 * Security Model:
 * - DEFAULT_ADMIN_ROLE manages roles
 * - MINTER_ROLE can mint
 * - BURNER_ROLE can burn
 *
 * Monetary policy (caps, rate limits, collateral logic) is enforced
 * by higher-level protocol contracts (Vault/Treasury).
 */
contract NXUSDToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice Maximum total supply of NXUSD. 0 = no cap enforced (default).
    ///         Governance must call setMaxSupply() to activate the cap.
    uint256 public maxSupply;

    event NXUSDMinted(address indexed to, uint256 amount, address indexed by);
    event NXUSDBurned(address indexed from, uint256 amount, address indexed by);
    event MaxSupplySet(uint256 maxSupply, address indexed by);

    constructor(address admin) ERC20("Nexus USD", "NXUSD") {
        require(admin != address(0), "NXUSD: admin is zero");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function setMaxSupply(uint256 maxSupply_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Allow setting to 0 (disables cap) or any value >= current supply.
        // Prevents governance from accidentally freezing all future minting by
        // setting a cap below what already exists.
        require(maxSupply_ == 0 || maxSupply_ >= totalSupply(), "NXUSD: cap below current supply");
        maxSupply = maxSupply_;
        emit MaxSupplySet(maxSupply_, msg.sender);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(to != address(0), "NXUSD: to is zero");
        require(amount > 0, "NXUSD: amount is zero");
        // Enforce supply cap. Cap is active when maxSupply > 0.
        // Checked here (not in VaultManager) so that any future minter granted
        // via setMinter() is also subject to the cap.
        require(maxSupply == 0 || totalSupply() + amount <= maxSupply, "NXUSD: supply cap exceeded");

        _mint(to, amount);

        emit NXUSDMinted(to, amount, msg.sender);
    }

    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        require(from != address(0), "NXUSD: from is zero");
        require(amount > 0, "NXUSD: amount is zero");

        _burn(from, amount);

        emit NXUSDBurned(from, amount, msg.sender);
    }

    function setMinter(address account, bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(account != address(0), "NXUSD: account is zero");

        if (enabled) {
            _grantRole(MINTER_ROLE, account);
        } else {
            _revokeRole(MINTER_ROLE, account);
        }
    }

    function setBurner(address account, bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(account != address(0), "NXUSD: account is zero");

        if (enabled) {
            _grantRole(BURNER_ROLE, account);
        } else {
            _revokeRole(BURNER_ROLE, account);
        }
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

