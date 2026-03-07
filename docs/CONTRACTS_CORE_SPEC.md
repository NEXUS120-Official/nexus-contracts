# NEXUS Contracts - Core Spec

## Modules

### NXUSDToken
Role-gated ERC20 stable asset with:
- MINTER_ROLE
- BURNER_ROLE
- admin helper setters

### OracleModule
Read-only oracle wrapper with:
- stale check
- non-positive price rejection
- admin-configurable feed and max delay

### VaultManager
Collateralized vault with:
- deposit / withdraw
- mint / burn
- collateral ratio enforcement
- liquidation preview
- keeper-only liquidation entrypoint

### LiquidationEngine
Keeper-driven liquidation executor with:
- close factor enforcement
- vault integration
- collateral seizure through vault liquidation flow

## Current Protocol Parameters
- min collateral ratio: 15000 bps
- liquidation ratio: 13000 bps
- close factor: 5000 bps
- liquidation bonus: 10500 bps
- max oracle delay: 3600 seconds
