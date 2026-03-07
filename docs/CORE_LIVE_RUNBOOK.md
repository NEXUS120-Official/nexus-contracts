# NEXUS Contracts - Core Live Runbook

## Objective
Validate the real core stack on Arbitrum Sepolia using:
- real WETH collateral
- official ETH/USD oracle feed
- live vault deposit
- live NXUSD mint
- state verification after execution

## Prerequisites
- CORE_NXUSD set in .env
- CORE_ORACLE set in .env
- CORE_VAULT set in .env
- CORE_LIQUIDATION_ENGINE set in .env
- COLLATERAL_TOKEN set in .env
- ORACLE_FEED set in .env
- wallet holds WETH on Arbitrum Sepolia

## WETH Wrap Example
    cast send $COLLATERAL_TOKEN "deposit()" --value 0.02ether --private-key $PRIVATE_KEY --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

## Balance Check
    cast call $COLLATERAL_TOKEN "balanceOf(address)(uint256)" $ADMIN --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

## Dry Run
    forge script script/CoreLiveScenario.s.sol:CoreLiveScenario --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

## Broadcast
    forge script script/CoreLiveScenario.s.sol:CoreLiveScenario --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast

## Expected Result
- vault deposit succeeds
- NXUSD mint succeeds
- oracle read succeeds
- final debt and collateral match expectations

## Live Result Snapshot
- oracle price: 196970156047
- oracle updatedAt: 1772910419
- deposit amount: 10000000000000000
- mint amount: 5000000000000000000
- vault debt: 5000000000000000000
- vault collateral: 10000000000000000
