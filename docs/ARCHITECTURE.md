# NEXUS FINANCE ARCHITECTURE

## Overview

NEXUS Finance is a modular decentralized credit infrastructure designed around overcollateralized credit issuance, collateralized vault management, liquidation enforcement, and governance-aware control surfaces.

The protocol is structured to support resilient on-chain dollar markets through deterministic execution logic, explicit collateral constraints, and institutional-grade operational discipline.

This repository focuses on the public smart contract layer and its directly related protocol documentation.

## System Architecture

At a high level, the protocol can be understood across five core layers:

1. collateralized vault lifecycle
2. credit issuance and debt accounting
3. repayment and position recovery
4. liquidation enforcement
5. governance-sensitive administration

These layers work together to maintain predictable protocol behavior and controlled risk surfaces.

## Core Modules

The public contracts package currently centers around the following modules:

- `NXUSDToken`
- `OracleModule`
- `VaultManager`
- `LiquidationEngine`

A more compact module summary is available in `CONTRACTS_CORE_SPEC.md`.

## Vault Lifecycle

The vault layer manages collateralized positions throughout their lifecycle.

Its responsibilities include:

- vault creation and activation
- collateral deposit and withdrawal flows
- collateral tracking
- position state transitions
- integration with mint, repay, and liquidation paths

Vaults act as the protocol’s core state container for collateralized credit issuance.

## Credit Issuance

The credit issuance layer governs how protocol credit is created against eligible collateral.

Its design goals include:

- overcollateralization enforcement
- constrained issuance logic
- predictable debt accounting
- explicit dependency on protocol-defined collateral rules

This is intended to preserve disciplined credit creation rather than unconstrained token expansion.

## Repayment and Recovery

The repayment layer allows positions to move back toward safer collateral states or to fully close debt obligations.

Its functions include:

- repayment flows
- debt reduction
- position normalization
- lifecycle completion for closed obligations

This layer is necessary for full lifecycle integrity.

## Liquidation Enforcement

The liquidation layer exists to handle unsafe positions when collateral conditions are no longer sufficient.

Its responsibilities include:

- breach detection through protocol rules
- liquidation eligibility checks
- execution pathways for unhealthy vaults
- collateral seizure logic through enforced liquidation flow

Liquidation is treated as a primary stability mechanism, not as an auxiliary feature.

## Governance Surfaces

NEXUS Finance incorporates governance-aware control surfaces designed to reduce dependence on informal operator trust.

The governance direction of the protocol emphasizes:

- Safe-based administrative hardening
- controlled privileged actions
- separated operational roles
- replayable and registry-backed operational state

Additional governance detail is documented in `MULTISIG_GOVERNANCE_ARCHITECTURE.md`.

## Public Repository Scope

This public repository is intended to expose the smart contract surface and a clean public-facing protocol view.

It does not attempt to expose every internal workflow, fundraising process, or deeper infrastructure component associated with the broader NEXUS Finance system.

## Current Stage

The current protocol stage includes validated lifecycle behavior across:

- vault activation
- mint
- repay
- liquidation

Development remains active on Arbitrum Sepolia as part of the protocol’s pre-mainnet infrastructure phase.
