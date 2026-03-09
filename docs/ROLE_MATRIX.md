# ROLE MATRIX — NEXUS CONTRACTS

Status: CANONICAL DRAFT
Standard: TOP-5 ELITE / audit-grade
Repo: nexus-contracts
Branch: law-phase1
Network: Arbitrum Sepolia

--------------------------------------------------

1. PURPOSE

This document defines the canonical role matrix
for the NEXUS CONTRACTS on-chain layer.

Objectives:

- enumerate privileged roles
- document current role holders
- define institutional target holders
- support governance migration planning
- support audit evidence packaging
- serve as governance source-of-truth

This document is governance-critical.

--------------------------------------------------

2. GOVERNANCE DESIGN PRINCIPLES

The governance architecture follows
institutional protocol design principles.

1. Least privilege

Each actor must hold only the
minimum authority required.

2. Separation of powers

Admin, guardian and keeper
roles must remain separated.

3. Operational replayability

All governance changes must
be reproducible via runbooks.

4. Emergency controllability

Emergency pause capability
must remain operational.

5. Administrative minimization

EOA concentration must be
eliminated before production.

--------------------------------------------------

3. CURRENT GOVERNANCE POSTURE

Current deployment posture:

admin authority
single EOA

guardian authority
same EOA

keeper authority
same EOA

Emergency pause rails exist.

Architecture already supports
role separation.

Operational separation
not yet implemented.

This is acceptable for
testnet validation stage.

--------------------------------------------------

4. TARGET GOVERNANCE POSTURE

Admin roles

held by governance multisig.

Guardian roles

held by independent authority.

Keeper roles

held by operational bots.

Protocol roles

held by contracts whenever possible.

EOA concentration must disappear.

--------------------------------------------------

5. CORE ROLE MATRIX

5.1 NXUSDToken

DEFAULT_ADMIN_ROLE

Purpose:
governance root authority.

Current holder:
Admin EOA

Target holder:
Governance multisig

MINTER_ROLE

Purpose:
mint NXUSD for protocol.

Current holder:
VaultManager contract

Target holder:
VaultManager contract

BURNER_ROLE

Purpose:
burn NXUSD on debt repayment.

Current holder:
VaultManager contract

Target holder:
VaultManager contract

--------------------------------------------------

5.2 OracleModule

DEFAULT_ADMIN_ROLE

Purpose:
configure oracle feed.

Current holder:
Admin EOA

Target holder:
Governance multisig

--------------------------------------------------

5.3 VaultManager

DEFAULT_ADMIN_ROLE

Purpose:
protocol configuration.

Current holder:
Admin EOA

Target holder:
Governance multisig

GUARDIAN_ROLE

Purpose:
emergency pause authority.

Current holder:
Admin EOA

Target holder:
guardian authority

--------------------------------------------------

5.4 LiquidationEngine

DEFAULT_ADMIN_ROLE

Purpose:
engine configuration.

Current holder:
Admin EOA

Target holder:
Governance multisig

KEEPER_ROLE

Purpose:
execute liquidations.

Current holder:
Admin EOA

Target holder:
keeper operators

--------------------------------------------------

Core governance principle

ADMIN != GUARDIAN != KEEPER
