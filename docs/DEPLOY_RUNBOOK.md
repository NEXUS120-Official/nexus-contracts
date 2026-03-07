# NEXUS Contracts - Deploy Runbook

## Network
Arbitrum Sepolia (chainId 421614)

## Prerequisites
- Foundry installed
- .env populated with:
  - ARBITRUM_SEPOLIA_RPC_URL
  - PRIVATE_KEY
  - ADMIN
  - KEEPER

## Smoke Deploy
Command:
    source .env && forge script script/DeploySmokeStack.s.sol:DeploySmokeStack --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast

## Core Deploy
Command:
    source .env && forge script script/DeployCore.s.sol:DeployCore --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast

## Post-Deploy Checks
- Confirm contract addresses emitted in logs
- Confirm broadcast artifact exists under broadcast/
- Confirm roles wired:
  - Vault is NXUSD minter
  - Vault is NXUSD burner
  - LiquidationEngine is Vault keeper
  - Keeper wallet is LiquidationEngine keeper
