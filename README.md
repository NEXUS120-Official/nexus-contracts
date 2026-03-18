# NEXUS Finance — Smart Contracts

> Sovereign credit infrastructure contracts on Arbitrum Sepolia.

## Deployed Contracts (Arbitrum Sepolia)

| Contract | Address | Status |
|----------|---------|--------|
| NXUSDToken | 0x515844Dd91956C749e33521B4f171dac4e04FE07 | ● Live |
| VaultManager | 0xF09AAD220C6c4d805cF6cE5561B546f51ADFBb03 | ● Live |
| LiquidationEngine | 0xF333d9ae2D70305758E714ecBeA938e9377a9f9D | ● Live |
| OracleModule | 0xa1BD5AF1174140caB018e46eBCFEf1d005c3df84 | ● Live |
| WETH (collateral) | 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73 | ● Live |
| Safe Multisig | 0x8626240187bb366a8566D338b84a7F84f237164F | ● Live |

## Architecture

- Min collateral ratio: 150% (15000 bps)
- Liquidation threshold: 130% (13000 bps)
- Keeper bonus: 5%
- Oracle: Chainlink ETH/USD with staleness check (maxDelay: 1 hour)
- Governance: Safe 4-of-7 multisig

## Development

```bash
forge build
forge test
forge script script/DeployCoreHardened.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast
```

## Repository Structure

```
nexus-contracts/
├── src/
│   ├── core/          # NXUSDToken.sol
│   ├── vault/         # VaultManager.sol, LiquidationEngine.sol
│   └── oracle/        # OracleModule.sol
├── script/            # Foundry deployment scripts
├── test/              # Forge test suites
├── deployments/       # JSON address registries
└── constitution/      # Invariants and constitution engine
```

## Live Engine

The NEXUS-120 Engine reads these contracts every tick:
[NEXUS120-Official/nexus-120-engine](https://github.com/NEXUS120-Official/nexus-120-engine)

## License

Proprietary — NEXUS Finance © 2026
