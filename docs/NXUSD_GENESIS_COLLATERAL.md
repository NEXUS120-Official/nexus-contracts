# NXUSD GENESIS COLLATERAL

Date: 2026-03-09

Protocol: NEXUS FINANCE

## Objective

Define the first canonical collateral asset used to bootstrap NXUSD issuance.

## Genesis Collateral

ETH

## Rationale

ETH is selected as the genesis collateral because it provides:

- the deepest crypto-native liquidity base
- the highest market recognition
- the strongest integration potential across DeFi
- the lowest complexity for protocol bootstrapping

## Genesis Credit Path

ETH
→ VaultManager
→ collateralized position
→ mint NXUSD

## Initial Risk Doctrine

- ETH is the only genesis collateral
- all initial minting activity must be overcollateralized
- liquidation safety remains mandatory
- oracle integrity remains mandatory
- governance may not bypass constitution invariants

## Expansion Path

After successful ETH genesis activation, the next collateral candidates are:

1. wstETH
2. BTC wrappers
3. selected high-quality yield-bearing assets

## Genesis Principle

NXUSD must begin with the cleanest and most legible collateral base possible.

ETH is the canonical first asset for that purpose.
