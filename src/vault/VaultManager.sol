// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Pausable} from "openzeppelin-contracts/contracts/utils/Pausable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface INXUSD {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

interface IOracleModule {
    function getPrice() external view returns (uint256 price, uint256 updatedAt, uint8 decimals);
}

contract VaultManager is AccessControl, Pausable {
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    /// @notice Hard upper bound on maxDelay. Prevents disabling freshness checks
    ///         via extreme values (e.g. type(uint256).max). 7 days is generous
    ///         enough for irregular testnet feeds while blocking the attack vector.
    uint256 public constant MAX_DELAY = 7 days;

    IERC20 public immutable COLLATERAL;
    INXUSD public immutable NXUSD;
    IOracleModule public oracle;

    uint256 public minCollateralRatioBps;
    uint256 public liquidationRatioBps;
    uint256 public maxDelay;

    mapping(address => uint256) public collateralOf;
    mapping(address => uint256) public debtOf;

    /// @notice H-04 FIX: Cumulative NXUSD debt written off via resolveBadDebt().
    ///         Represents NXUSD supply that is no longer backed by protocol collateral.
    ///         Governance must address undercollateralized supply via recapitalization.
    uint256 public totalBadDebt;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Mint(address indexed user, uint256 amount);
    event Burn(address indexed user, uint256 amount);

    event OracleSet(address oracle, address indexed by);
    event RatiosSet(uint256 minCrBps, uint256 liqCrBps, address indexed by);
    event MaxDelaySet(uint256 maxDelay, address indexed by);

    event Liquidated(address indexed account, address indexed liquidator, uint256 repayAmount, uint256 seizeAmount);

    /// @notice H-04 FIX: Emitted when a position is resolved via the emergency bad debt path.
    ///         collateralSeized: all remaining collateral transferred to the guardian caller.
    ///         debtCleared: full debt amount cleared from vault accounting.
    ///         badDebt: uncovered portion of debt (debtCleared minus what collateral could cover).
    ///         resolvedBy: the GUARDIAN_ROLE address that called resolveBadDebt().
    event BadDebtResolved(
        address indexed account,
        uint256 collateralSeized,
        uint256 debtCleared,
        uint256 badDebt,
        address indexed resolvedBy
    );

    constructor(
        address admin,
        address collateral_,
        address nxusd_,
        address oracle_,
        uint256 minCrBps_,
        uint256 liqCrBps_,
        uint256 maxDelay_
    ) {
        require(admin != address(0), "VAULT: admin is zero");
        require(collateral_ != address(0), "VAULT: collateral is zero");
        require(nxusd_ != address(0), "VAULT: nxusd is zero");
        require(oracle_ != address(0), "VAULT: oracle is zero");

        require(minCrBps_ >= 10000, "VAULT: minCR < 100%");
        require(liqCrBps_ >= 10000, "VAULT: liqCR < 100%");
        require(minCrBps_ >= liqCrBps_, "VAULT: minCR < liqCR");

        require(maxDelay_ > 0, "VAULT: maxDelay is zero");
        require(maxDelay_ <= MAX_DELAY, "VAULT: maxDelay too large");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GUARDIAN_ROLE, admin);

        COLLATERAL = IERC20(collateral_);
        NXUSD = INXUSD(nxusd_);
        oracle = IOracleModule(oracle_);

        minCollateralRatioBps = minCrBps_;
        liquidationRatioBps = liqCrBps_;
        maxDelay = maxDelay_;

        emit OracleSet(oracle_, admin);
        emit RatiosSet(minCrBps_, liqCrBps_, admin);
        emit MaxDelaySet(maxDelay_, admin);
    }

    function setOracle(address oracle_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(oracle_ != address(0), "VAULT: oracle is zero");
        // Smoke-check: verify the candidate implements IOracleModule and currently
        // returns a positive price. Catches mis-addressed contracts and contracts
        // that do not implement the interface at commit time.
        // Note: if the oracle's underlying feed is currently stale, this call will
        // revert; setOracle should only be called while the candidate oracle is live.
        (uint256 price,,) = IOracleModule(oracle_).getPrice();
        require(price > 0, "VAULT: new oracle zero price");
        oracle = IOracleModule(oracle_);
        emit OracleSet(oracle_, msg.sender);
    }

    function setRatios(uint256 minCrBps_, uint256 liqCrBps_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(minCrBps_ >= 10000, "VAULT: minCR < 100%");
        require(liqCrBps_ >= 10000, "VAULT: liqCR < 100%");
        require(minCrBps_ >= liqCrBps_, "VAULT: minCR < liqCR");

        minCollateralRatioBps = minCrBps_;
        liquidationRatioBps = liqCrBps_;

        emit RatiosSet(minCrBps_, liqCrBps_, msg.sender);
    }

    function setMaxDelay(uint256 maxDelay_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(maxDelay_ > 0, "VAULT: maxDelay is zero");
        require(maxDelay_ <= MAX_DELAY, "VAULT: maxDelay too large");
        maxDelay = maxDelay_;
        emit MaxDelaySet(maxDelay_, msg.sender);
    }

    function deposit(uint256 amount) external whenNotPaused {
        require(amount > 0, "VAULT: amount is zero");

        collateralOf[msg.sender] += amount;

        require(COLLATERAL.transferFrom(msg.sender, address(this), amount), "VAULT: transferFrom failed");

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external whenNotPaused {
        require(amount > 0, "VAULT: amount is zero");
        require(collateralOf[msg.sender] >= amount, "VAULT: insufficient collateral");

        collateralOf[msg.sender] -= amount;

        require(_isSafe(msg.sender), "VAULT: unsafe after withdraw");

        require(COLLATERAL.transfer(msg.sender, amount), "VAULT: transfer failed");

        emit Withdraw(msg.sender, amount);
    }

    function mint(uint256 amount) external whenNotPaused {
        require(amount > 0, "VAULT: amount is zero");

        debtOf[msg.sender] += amount;

        require(_isSafe(msg.sender), "VAULT: unsafe mint");

        NXUSD.mint(msg.sender, amount);

        emit Mint(msg.sender, amount);
    }

    function burn(uint256 amount) external whenNotPaused {
        require(amount > 0, "VAULT: amount is zero");
        require(debtOf[msg.sender] >= amount, "VAULT: burn exceeds debt");

        debtOf[msg.sender] -= amount;

        NXUSD.burn(msg.sender, amount);

        emit Burn(msg.sender, amount);
    }

    function _oracleSnapshot() internal view returns (uint256 price, uint256 updatedAt, uint8 dec) {
        (price, updatedAt, dec) = oracle.getPrice();

        require(updatedAt > 0, "VAULT: oracle no update");
        require(block.timestamp >= updatedAt, "VAULT: oracle time skew");
        require(block.timestamp - updatedAt <= maxDelay, "VAULT: oracle stale");
    }

    function _isSafe(address account) internal view returns (bool) {
        uint256 d = debtOf[account];
        if (d == 0) return true;

        uint256 col = collateralOf[account];
        if (col == 0) return false;

        (uint256 price,, uint8 dec) = _oracleSnapshot();

        uint256 denom = 10 ** uint256(dec);
        uint256 value18 = (col * price) / denom;

        return value18 * 10000 >= d * minCollateralRatioBps;
    }

    function isLiquidatable(address account) external view returns (bool) {
        uint256 d = debtOf[account];
        if (d == 0) return false;

        uint256 col = collateralOf[account];
        if (col == 0) return true;

        (uint256 price,, uint8 dec) = _oracleSnapshot();

        uint256 denom = 10 ** uint256(dec);
        uint256 value18 = (col * price) / denom;

        return value18 * 10000 < d * liquidationRatioBps;
    }

    function liquidationPreview(address account, uint256 repayAmount) external view returns (uint256 seizeAmount) {
        require(repayAmount > 0, "VAULT: repay is zero");

        uint256 d = debtOf[account];
        require(d > 0, "VAULT: no debt");

        uint256 col = collateralOf[account];
        require(col > 0, "VAULT: no collateral");

        (uint256 price,, uint8 dec) = _oracleSnapshot();

        uint256 denom = 10 ** uint256(dec);

        uint256 bonusAdjusted = (repayAmount * 10500) / 10000;
        seizeAmount = (bonusAdjusted * denom) / price;

        require(seizeAmount <= col, "VAULT: seize exceeds collateral");
    }

    function _seizeAmountForRepay(uint256 repayAmount, uint256 price, uint8 dec)
        internal
        pure
        returns (uint256 seizeAmount)
    {
        uint256 denom = 10 ** uint256(dec);
        uint256 bonusAdjusted = (repayAmount * 10500) / 10000;

        seizeAmount = (bonusAdjusted * denom) / price;
    }

    function liquidate(address account, address liquidator, uint256 repayAmount)
        external
        onlyRole(KEEPER_ROLE)
        whenNotPaused
        returns (uint256 seizeAmount)
    {
        require(account != address(0), "VAULT: account is zero");
        require(liquidator != address(0), "VAULT: liquidator is zero");
        require(repayAmount > 0, "VAULT: repay is zero");

        uint256 d = debtOf[account];
        require(d > 0, "VAULT: no debt");

        uint256 col = collateralOf[account];
        require(col > 0, "VAULT: no collateral");

        (uint256 price,, uint8 dec) = _oracleSnapshot();

        uint256 denom = 10 ** uint256(dec);
        uint256 value18 = (col * price) / denom;

        require(value18 * 10000 < d * liquidationRatioBps, "VAULT: not liquidatable");

        if (repayAmount > d) {
            repayAmount = d;
        }

        seizeAmount = _seizeAmountForRepay(repayAmount, price, dec);
        require(seizeAmount <= col, "VAULT: seize exceeds collateral");

        debtOf[account] -= repayAmount;
        collateralOf[account] -= seizeAmount;

        // CEI: all state mutations are complete before any external call.
        // NXUSD is a protocol-controlled ERC-20 with no transfer hooks.
        // COLLATERAL (WETH) is immutable — it cannot be replaced with a token
        // that enables receiver callbacks. nonReentrant is not required here.
        NXUSD.burn(account, repayAmount);

        require(COLLATERAL.transfer(liquidator, seizeAmount), "VAULT: collateral transfer failed");

        emit Liquidated(account, liquidator, repayAmount, seizeAmount);
    }

    /// @notice H-04 FIX: Resolve a vault position that is irrecoverably underwater.
    ///
    ///         Normal liquidation reverts when the 5% keeper bonus causes the required
    ///         seize amount to exceed available collateral. Positions in that range
    ///         become permanently stuck with no protocol resolution path.
    ///
    ///         This function provides a controlled emergency path:
    ///           - Only callable by GUARDIAN_ROLE.
    ///           - Only callable when the position is objectively irrecoverable:
    ///             _seizeAmountForRepay(fullDebt, price) > remaining collateral.
    ///           - Seizes all remaining collateral and transfers it to the caller.
    ///           - Clears debtOf and collateralOf for the account (replay-safe).
    ///           - Increments totalBadDebt with the uncovered debt portion.
    ///           - Does NOT enforce whenNotPaused: guardian should be able to clear
    ///             bad debt positions even while the vault is paused for incident response.
    ///
    ///         The NXUSD corresponding to the cleared debt remains in circulation as
    ///         undercollateralized supply. Governance must address this via a separate
    ///         recapitalization or burn mechanism.
    ///
    /// @param  account  The vault position to resolve.
    /// @return seized   Amount of collateral transferred to the guardian caller.
    function resolveBadDebt(address account) external onlyRole(GUARDIAN_ROLE) returns (uint256 seized) {
        require(account != address(0), "VAULT: account is zero");

        uint256 debt = debtOf[account];
        require(debt > 0, "VAULT: no debt");

        uint256 col = collateralOf[account];

        (uint256 price,, uint8 dec) = _oracleSnapshot();

        // Verify the position cannot be resolved through the normal liquidation path.
        // Uses the same arithmetic as liquidate() to ensure consistency:
        // normal liquidation reverts when _seizeAmountForRepay(fullDebt) > col.
        uint256 seizeForFull = _seizeAmountForRepay(debt, price, dec);
        require(seizeForFull > col, "VAULT: not bad debt");

        // Compute the uncovered debt portion.
        // The collateral covers at most: covered = col * price * 10000 / (denom * 10500)
        // (inverse of _seizeAmountForRepay). Since seizeForFull > col, covered < debt.
        uint256 denom = 10 ** uint256(dec);
        uint256 covered = (col * price * 10000) / (denom * 10500);
        uint256 bad = debt - covered; // underflow impossible: proven above

        seized = col;

        // CEI: clear vault state before any external call.
        debtOf[account] = 0;
        collateralOf[account] = 0;
        totalBadDebt += bad;

        emit BadDebtResolved(account, seized, debt, bad, msg.sender);

        // Transfer remaining collateral to the guardian. Skipped if col == 0
        // (position had debt but no collateral — fully underwater).
        if (seized > 0) {
            require(COLLATERAL.transfer(msg.sender, seized), "VAULT: collateral transfer failed");
        }
    }

    function pause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
