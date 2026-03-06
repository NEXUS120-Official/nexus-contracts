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

    event OracleSet(address indexed oracle, address indexed by);
    event RatiosSet(uint256 minCRBps, uint256 liqCRBps, address indexed by);
    event MaxDelaySet(uint256 maxDelay, address indexed by);

    event Deposit(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 amount);
    event MintNXUSD(address indexed account, uint256 amount);
    event BurnNXUSD(address indexed account, uint256 amount);

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
        require(collateral.transferFrom(msg.sender, address(this), amount), "VAULT: transferFrom failed");
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

        require(_isSafe(msg.sender), "VAULT: insufficient collateral");

        nxusd.mint(msg.sender, amount);
        emit MintNXUSD(msg.sender, amount);
    }

    function burn(uint256 amount) external {
        require(amount > 0, "VAULT: amount is zero");
        require(debtOf[msg.sender] >= amount, "VAULT: insufficient debt");

        debtOf[msg.sender] -= amount;

        nxusd.burn(msg.sender, amount);
        emit BurnNXUSD(msg.sender, amount);
    }

    function _isSafe(address account) internal view returns (bool) {
        uint256 d = debtOf[account];
        if (d == 0) return true;

        uint256 col = collateralOf[account];
        if (col == 0) return false;

        (uint256 price, uint256 updatedAt, uint8 dec) = oracle.getPrice();

        require(updatedAt > 0, "VAULT: oracle no update");
        require(block.timestamp >= updatedAt, "VAULT: oracle time skew");
        require(block.timestamp - updatedAt <= maxDelay, "VAULT: oracle stale");

        uint256 denom = 10 ** uint256(dec);
        uint256 value18 = (col * price) / denom;

        return value18 * 10000 >= d * minCollateralRatioBps;
    }
}
