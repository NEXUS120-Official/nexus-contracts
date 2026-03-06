// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface INXUSD {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

interface IOracleModule {
    function getPrice()
        external
        view
        returns (uint256 price, uint256 updatedAt, uint8 decimals);
}

contract VaultManager is AccessControl {

    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    IERC20 public immutable collateral;
    INXUSD public immutable nxusd;
    IOracleModule public oracle;

    uint256 public minCollateralRatioBps;
    uint256 public liquidationRatioBps;
    uint256 public maxDelay;

    mapping(address => uint256) public collateralOf;
    mapping(address => uint256) public debtOf;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Mint(address indexed user, uint256 amount);
    event Burn(address indexed user, uint256 amount);

    event OracleSet(address oracle, address indexed by);
    event RatiosSet(uint256 minCRBps, uint256 liqCRBps, address indexed by);
    event MaxDelaySet(uint256 maxDelay, address indexed by);

    event Liquidated(
        address indexed account,
        address indexed liquidator,
        uint256 repayAmount,
        uint256 seizeAmount
    );

    constructor(
        address admin,
        address collateral_,
        address nxusd_,
        address oracle_,
        uint256 minCRBps_,
        uint256 liqCRBps_,
        uint256 maxDelay_
    ) {

        require(admin != address(0), "VAULT: admin is zero");
        require(collateral_ != address(0), "VAULT: collateral is zero");
        require(nxusd_ != address(0), "VAULT: nxusd is zero");
        require(oracle_ != address(0), "VAULT: oracle is zero");

        require(minCRBps_ >= 10000, "VAULT: minCR < 100%");
        require(liqCRBps_ >= 10000, "VAULT: liqCR < 100%");
        require(minCRBps_ >= liqCRBps_, "VAULT: minCR < liqCR");

        require(maxDelay_ > 0, "VAULT: maxDelay is zero");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        collateral = IERC20(collateral_);
        nxusd = INXUSD(nxusd_);
        oracle = IOracleModule(oracle_);

        minCollateralRatioBps = minCRBps_;
        liquidationRatioBps = liqCRBps_;
        maxDelay = maxDelay_;

        emit OracleSet(oracle_, admin);
        emit RatiosSet(minCRBps_, liqCRBps_, admin);
        emit MaxDelaySet(maxDelay_, admin);
    }

    function setOracle(address oracle_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(oracle_ != address(0), "VAULT: oracle is zero");
        oracle = IOracleModule(oracle_);
        emit OracleSet(oracle_, msg.sender);
    }

    function setRatios(uint256 minCRBps_, uint256 liqCRBps_)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(minCRBps_ >= 10000, "VAULT: minCR < 100%");
        require(liqCRBps_ >= 10000, "VAULT: liqCR < 100%");
        require(minCRBps_ >= liqCRBps_, "VAULT: minCR < liqCR");

        minCollateralRatioBps = minCRBps_;
        liquidationRatioBps = liqCRBps_;

        emit RatiosSet(minCRBps_, liqCRBps_, msg.sender);
    }

    function setMaxDelay(uint256 maxDelay_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(maxDelay_ > 0, "VAULT: maxDelay is zero");
        maxDelay = maxDelay_;
        emit MaxDelaySet(maxDelay_, msg.sender);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "VAULT: amount is zero");

        collateralOf[msg.sender] += amount;

        require(
            collateral.transferFrom(msg.sender, address(this), amount),
            "VAULT: transferFrom failed"
        );

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "VAULT: amount is zero");
        require(collateralOf[msg.sender] >= amount, "VAULT: insufficient collateral");

        collateralOf[msg.sender] -= amount;

        require(_isSafe(msg.sender), "VAULT: unsafe after withdraw");

        require(collateral.transfer(msg.sender, amount), "VAULT: transfer failed");

        emit Withdraw(msg.sender, amount);
    }

    function mint(uint256 amount) external {
        require(amount > 0, "VAULT: amount is zero");

        debtOf[msg.sender] += amount;

        require(_isSafe(msg.sender), "VAULT: unsafe mint");

        nxusd.mint(msg.sender, amount);

        emit Mint(msg.sender, amount);
    }

    function burn(uint256 amount) external {
        require(amount > 0, "VAULT: amount is zero");
        require(debtOf[msg.sender] >= amount, "VAULT: burn exceeds debt");

        debtOf[msg.sender] -= amount;

        nxusd.burn(msg.sender, amount);

        emit Burn(msg.sender, amount);
    }

    function _oracleSnapshot()
        internal
        view
        returns (uint256 price, uint256 updatedAt, uint8 dec)
    {
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

        (uint256 price,,uint8 dec) = _oracleSnapshot();

        uint256 denom = 10 ** uint256(dec);
        uint256 value18 = (col * price) / denom;

        return value18 * 10000 >= d * minCollateralRatioBps;
    }

    function isLiquidatable(address account) external view returns (bool) {

        uint256 d = debtOf[account];
        if (d == 0) return false;

        uint256 col = collateralOf[account];
        if (col == 0) return true;

        (uint256 price,,uint8 dec) = _oracleSnapshot();

        uint256 denom = 10 ** uint256(dec);
        uint256 value18 = (col * price) / denom;

        return value18 * 10000 < d * liquidationRatioBps;
    }

    function liquidationPreview(address account, uint256 repayAmount)
        external
        view
        returns (uint256 seizeAmount)
    {

        require(repayAmount > 0, "VAULT: repay is zero");

        uint256 d = debtOf[account];
        require(d > 0, "VAULT: no debt");

        uint256 col = collateralOf[account];
        require(col > 0, "VAULT: no collateral");

        (uint256 price,,uint8 dec) = _oracleSnapshot();

        uint256 denom = 10 ** uint256(dec);

        uint256 bonusAdjusted = (repayAmount * 10500) / 10000;
        seizeAmount = (bonusAdjusted * denom) / price;

        require(seizeAmount <= col, "VAULT: seize exceeds collateral");
    }

    function _seizeAmountForRepay(
        uint256 repayAmount,
        uint256 price,
        uint8 dec
    ) internal pure returns (uint256 seizeAmount) {

        uint256 denom = 10 ** uint256(dec);
        uint256 bonusAdjusted = (repayAmount * 10500) / 10000;

        seizeAmount = (bonusAdjusted * denom) / price;
    }

    function liquidate(
        address account,
        address liquidator,
        uint256 repayAmount
    )
        external
        onlyRole(KEEPER_ROLE)
        returns (uint256 seizeAmount)
    {

        require(account != address(0), "VAULT: account is zero");
        require(liquidator != address(0), "VAULT: liquidator is zero");
        require(repayAmount > 0, "VAULT: repay is zero");

        uint256 d = debtOf[account];
        require(d > 0, "VAULT: no debt");

        uint256 col = collateralOf[account];
        require(col > 0, "VAULT: no collateral");

        (uint256 price,,uint8 dec) = _oracleSnapshot();

        uint256 denom = 10 ** uint256(dec);
        uint256 value18 = (col * price) / denom;

        require(
            value18 * 10000 < d * liquidationRatioBps,
            "VAULT: not liquidatable"
        );

        if (repayAmount > d) {
            repayAmount = d;
        }

        seizeAmount = _seizeAmountForRepay(repayAmount, price, dec);
        require(seizeAmount <= col, "VAULT: seize exceeds collateral");

        debtOf[account] -= repayAmount;
        collateralOf[account] -= seizeAmount;

        nxusd.burn(account, repayAmount);

        require(
            collateral.transfer(liquidator, seizeAmount),
            "VAULT: collateral transfer failed"
        );

        emit Liquidated(account, liquidator, repayAmount, seizeAmount);
    }

}
