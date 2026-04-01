// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Pausable} from "openzeppelin-contracts/contracts/utils/Pausable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IVaultLiquidation {
    function debtOf(address account) external view returns (uint256);
    function isLiquidatable(address account) external view returns (bool);
    function liquidate(address account, address liquidator, uint256 repayAmount) external returns (uint256 seizeAmount);
}

contract LiquidationEngine is AccessControl, Pausable {
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    IERC20 public immutable NXUSD;
    IVaultLiquidation public vault;

    uint256 public closeFactorBps;

    event CloseFactorSet(uint256 closeFactorBps, address indexed by);
    event VaultSet(address indexed vault, address indexed by);

    event LiquidationExecuted(
        address indexed account, address indexed liquidator, uint256 repayAmount, uint256 seizeAmount
    );

    constructor(address admin, address nxusd_, address vault_, uint256 closeFactorBps_) {
        require(admin != address(0), "LIQ: admin is zero");
        require(nxusd_ != address(0), "LIQ: nxusd is zero");
        require(vault_ != address(0), "LIQ: vault is zero");
        require(closeFactorBps_ > 0, "LIQ: close factor is zero");
        require(closeFactorBps_ <= 10000, "LIQ: close factor > 100%");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GUARDIAN_ROLE, admin);

        NXUSD = IERC20(nxusd_);
        vault = IVaultLiquidation(vault_);
        closeFactorBps = closeFactorBps_;

        emit VaultSet(vault_, admin);
        emit CloseFactorSet(closeFactorBps_, admin);
    }

    function setVault(address vault_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(vault_ != address(0), "LIQ: vault is zero");
        vault = IVaultLiquidation(vault_);
        emit VaultSet(vault_, msg.sender);
    }

    function setCloseFactor(uint256 closeFactorBps_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(closeFactorBps_ > 0, "LIQ: close factor is zero");
        require(closeFactorBps_ <= 10000, "LIQ: close factor > 100%");
        closeFactorBps = closeFactorBps_;
        emit CloseFactorSet(closeFactorBps_, msg.sender);
    }

    /// @notice Execute a partial or full liquidation of an undercollateralized vault.
    ///
    ///         Sequence (atomic — reverts entirely if any step fails):
    ///           1. Enforce close-factor: repayAmount ≤ debt * closeFactorBps / 10000.
    ///           2. Pull repayAmount NXUSD from keeper (transferFrom).
    ///           3. Forward NXUSD to the account so that vault.liquidate() can burn it.
    ///           4. Call vault.liquidate(), which burns from the account and transfers
    ///              seized collateral directly to the keeper (msg.sender).
    ///
    ///         Steps 2–4 are a single atomic EVM transaction. ERC-20 transfer has no
    ///         receiver hooks (not ERC-777), so no reentrancy window exists between
    ///         steps 3 and 4. If vault.liquidate() reverts for any reason, all three
    ///         token moves are unwound by the EVM.
    ///
    /// @param account      The vault position to liquidate.
    /// @param repayAmount  Amount of NXUSD to repay. Must not exceed close-factor cap.
    /// @return seizeAmount Amount of collateral transferred to the keeper.
    function executeLiquidation(address account, uint256 repayAmount)
        external
        onlyRole(KEEPER_ROLE)
        whenNotPaused
        returns (uint256 seizeAmount)
    {
        require(account != address(0), "LIQ: account is zero");
        require(repayAmount > 0, "LIQ: repay is zero");
        require(vault.isLiquidatable(account), "LIQ: vault not liquidatable");

        uint256 debt = vault.debtOf(account);
        require(debt > 0, "LIQ: no debt");

        uint256 maxRepay = (debt * closeFactorBps) / 10000;
        require(maxRepay > 0, "LIQ: max repay is zero");
        require(repayAmount <= maxRepay, "LIQ: exceeds close factor");

        require(NXUSD.transferFrom(msg.sender, address(this), repayAmount), "LIQ: transferFrom failed");

        require(NXUSD.transfer(account, repayAmount), "LIQ: transfer to account failed");

        seizeAmount = vault.liquidate(account, msg.sender, repayAmount);

        emit LiquidationExecuted(account, msg.sender, repayAmount, seizeAmount);
    }

    function pause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
