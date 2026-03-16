# NEXUS FINANCE REVIEW GUIDE

## Overview

This guide is intended to help external reviewers navigate the public NEXUS Finance contracts repository in a structured and efficient way.

It is designed for:

- auditors
- technical reviewers
- ecosystem counterparties
- accelerator reviewers
- diligence-oriented investors

The goal is to make the repository easier to interpret without requiring readers to infer the intended review path on their own.

## Recommended Reading Order

For most reviewers, the recommended reading order is:

1. `README.md`
2. `docs/ARCHITECTURE.md`
3. `docs/STATUS.md`
4. `docs/TESTNET_STATUS.md`
5. `docs/RISK_MODEL.md`

This sequence provides a high-level understanding of protocol identity, architecture, current stage, testnet posture, and public contract risk design.

## Additional Documentation

After the core reading path, reviewers may continue with:

- `docs/AUDIT_PACKAGE.md`
- `docs/CONSTITUTION.md`
- `docs/CONTRACTS_CORE_SPEC.md`
- `docs/MULTISIG_GOVERNANCE_ARCHITECTURE.md`

These materials provide more specific context around review support artifacts, constitutional structure, contract modules, and governance architecture.

## Repository Areas

Key public repository areas include:

- `src/` for core smart contracts
- `script/` for canonical Foundry deployment, verification, and scenario scripts
- `scripts/` for auxiliary repository utilities and generators
- `docs/` for public-facing protocol documentation
- `deployments/` for deployment-related public evidence
- `audit_package/` for audit-oriented support artifacts
- `constitution/` for the constitutional and invariant-oriented layer

## Review Notes

This repository is intended to expose the public smart contract surface and a structured documentation layer for NEXUS Finance.

It should be interpreted as a public contracts repository, not as an exhaustive exposure of every internal workflow, internal system component, or broader protocol-adjacent process.

## Reviewer Profiles

### For auditors and technical reviewers

Start with:

- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/RISK_MODEL.md`
- `docs/CONTRACTS_CORE_SPEC.md`

Then continue into:

- `src/`
- `script/`
- `deployments/`
- `audit_package/`

### For ecosystem and accelerator reviewers

Start with:

- `README.md`
- `docs/STATUS.md`
- `docs/TESTNET_STATUS.md`
- `docs/ARCHITECTURE.md`

Then continue into:

- `docs/MULTISIG_GOVERNANCE_ARCHITECTURE.md`
- `deployments/`

### For diligence-oriented investors

Start with:

- `README.md`
- `docs/STATUS.md`
- `docs/TESTNET_STATUS.md`
- `docs/ARCHITECTURE.md`
- `docs/AUDIT_PACKAGE.md`

Then continue into deeper technical material only as needed.

## Summary

The public NEXUS Finance contracts repository is organized to support structured external review across architecture, risk posture, governance-aware controls, deployment evidence, and contract-level technical diligence.
