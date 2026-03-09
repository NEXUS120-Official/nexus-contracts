# CHECKPOINT SAFE DEPLOYMENT PATH RESOLUTION — 2026-03-09

repo: nexus-contracts  
branch: law-phase1  
network: Arbitrum Sepolia

## Status

SAFE DEPLOYMENT PATH RESOLUTION: OPEN

## Current state

- multisig governance framework implemented
- signer set fixed at 4/7
- signer set funded
- no live governance cutover executed
- safe deployment path unresolved

## Hard constraints

- no governance cutover before Safe deployment is verified on Arbitrum Sepolia
- no deployment path may be assumed from memory
- Safe deployment must use an officially verified path
- final Safe address must be recorded in deployments/arbitrum-sepolia-multisig.json

## Accepted resolution paths

### Path A
Official Safe UI or officially supported Safe deployment endpoint verified for Arbitrum Sepolia.

### Path B
Official Safe contract deployment path verified on Arbitrum Sepolia using canonical deployed contracts and explicit Foundry execution.

## Next required deliverable

One of the following:

- verified Safe UI path
- verified Safe contract deployment path
- Safe address deployed on Arbitrum Sepolia

## Cutover remains blocked until

- Safe address exists on Arbitrum Sepolia
- Safe code presence verified
- multisig registry updated
