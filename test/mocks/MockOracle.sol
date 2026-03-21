// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

/// @dev Minimal IOracleModule stand-in.
/// Returns configured values without any validation, allowing VaultManager's
/// own _oracleSnapshot guards to be exercised independently of OracleModule's
/// equivalent checks.
contract MockOracle {
    uint256 public price;
    uint256 public updatedAt;
    uint8   public decimals;

    constructor() {
        price     = 2000e8;
        updatedAt = block.timestamp;
        decimals  = 8;
    }

    function setPrice(uint256 p) external { price = p; }
    function setUpdatedAt(uint256 t) external { updatedAt = t; }
    function setDecimals(uint8 d) external { decimals = d; }

    function getPrice() external view returns (uint256, uint256, uint8) {
        return (price, updatedAt, decimals);
    }
}
