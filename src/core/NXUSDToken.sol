// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

/**
 * @title NXUSDToken
 * @notice NXUSD is the USD-pegged stable asset of the NEXUS protocol.
 *         This contract is intentionally minimal: ERC20 + role-gated mint/burn.
 *
 *         Monetary policy (caps, rate-limits, collateral logic) is enforced by
 *         higher-level protocol contracts (Vault/Treasury) and governed by the
 *         Economic Constitution / Monetary Policy docs.
 */
contract NXUSDToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    event NXUSDMinted(address indexed to, uint256 amount, address indexed by);
    event NXUSDBurned(address indexed from, uint256 amount, address indexed by);

    constructor(address admin) ERC20("Nexus USD", "NXUSD") {
        require(admin != address(0), "NXUSD: admin is zero");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(to != address(0), "NXUSD: to is zero");
        require(amount > 0, "NXUSD: amount is zero");
        _mint(to, amount);
        emit NXUSDMinted(to, amount, msg.sender);
    }

    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        require(from != address(0), "NXUSD: from is zero");
        require(amount > 0, "NXUSD: amount is zero");
        _burn(from, amount);
        emit NXUSDBurned(from, amount, msg.sender);
    }
}
