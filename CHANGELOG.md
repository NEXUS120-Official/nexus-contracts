# Changelog

All notable changes to NEXUS Finance smart contracts are documented here.

---

## [Hardened Core] — 2026-03-18

### Deployed (Arbitrum Sepolia)
- **NXUSDToken** (`0x515844Dd91956C749e33521B4f171dac4e04FE07`) — ERC-20 overcollateralized credit asset
- **VaultManager** (`0xF09AAD220C6c4d805cF6cE5561B546f51ADFBb03`) — collateral vault with 150% min CR
- **LiquidationEngine** (`0xF333d9ae2D70305758E714ecBeA938e9377a9f9D`) — keeper liquidation at 130% CR
- **OracleModule** (`0xa1BD5AF1174140caB018e46eBCFEf1d005c3df84`) — Chainlink wrapper with staleness guard
- **Safe Multisig** (`0x8626240187bb366a8566D338b84a7F84f237164F`) — 4-of-7 governance multisig

### Validated On-Chain
- Vault deposit → NXUSD mint → repay → withdraw cycle
- Auto-liquidation at 130% CR
- Role-based access control (ADMIN, GUARDIAN, KEEPER)
- Oracle staleness rejection

---
