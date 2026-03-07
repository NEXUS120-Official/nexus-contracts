# NEXUS Contracts - Smoke Runbook

## Objective
Validate the full on-chain economic loop on Arbitrum Sepolia:
- mint mock collateral
- deposit collateral
- mint NXUSD
- drop oracle price
- execute liquidation
- verify resulting balances and debt

## Smoke Scenario Command
    source .env && forge script script/SmokeScenario.s.sol:SmokeScenario --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast

## Expected End State
- Partial liquidation executed successfully
- Vault debt reduced
- Liquidator receives collateral
- NXUSD balance reflects repayment
- Remaining collateral and debt are consistent with liquidation bonus and close factor

## Live Smoke Deployment Registry
See:
- deployments/arbitrum-sepolia-smoke.json

## Live Smoke Result Snapshot
- seized collateral: 875000000000000000
- admin NXUSD balance: 1000000000000000000000
- admin collateral balance: 8875000000000000000
- vault debt: 1000000000000000000000
- vault collateral: 1125000000000000000
