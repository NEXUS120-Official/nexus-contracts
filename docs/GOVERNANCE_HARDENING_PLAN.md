# NEXUS Contracts - Governance Hardening Plan

## Objectives
- minimize admin blast radius
- introduce emergency controls
- define mutable vs frozen parameters
- prepare multisig-ready governance posture

## Current Roles
- DEFAULT_ADMIN_ROLE
- MINTER_ROLE
- BURNER_ROLE
- KEEPER_ROLE

## Recommended Next Additions
- GUARDIAN_ROLE
- Pausable on critical state-changing modules
- bounded setters for protocol parameters
- optional timelock / multisig admin migration

## Mutable Parameters
- oracle max delay
- vault max delay
- min collateral ratio
- liquidation ratio
- close factor

## Required Bounds
- min collateral ratio >= liquidation ratio
- liquidation ratio >= 10000
- close factor > 0 and <= 10000
- max delay > 0
