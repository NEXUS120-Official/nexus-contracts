# GOVERNANCE MIGRATION SCENARIO RUNBOOK — NEXUS CONTRACTS

Status: CANONICAL DRAFT
Standard: TOP-5 ELITE / audit-grade / anti-drift / SSoT-ready
Repo: nexus-contracts
Branch: law-phase1
Network Scope: Arbitrum Sepolia

--------------------------------------------------

1. PURPOSE

This runbook defines the canonical
usage procedure for executing the
GovernanceMigrationScenario script
in the NEXUS CONTRACTS layer.

This document is governance-critical.

Primary objective:

validate staged governance grants
for guardian, keeper, and admin
before any destructive revoke sequence
is considered.

This runbook governs controlled scenario use.

--------------------------------------------------

2. SCRIPT SCOPE

The script in scope is:

script/GovernanceMigrationScenario.s.sol

Its purpose is to perform staged grant actions
and immediate on-chain verification for:

guardian topology extension

keeper topology extension

admin topology extension

This script does not perform revoke actions.

It is a grant-and-verify scenario tool,
not a full destructive migration tool.

--------------------------------------------------

3. REQUIRED INPUTS

Required env vars:

PRIVATE_KEY

NXUSD_TOKEN
ORACLE_MODULE
VAULT_MANAGER
LIQUIDATION_ENGINE

NEW_ADMIN
NEW_GUARDIAN
NEW_KEEPER

All addresses must be verified
before execution begins.

The script must be executed only
against the intended hardened live core.

--------------------------------------------------

4. PRECONDITIONS

Before running the scenario:

GovernanceVerify passes on current live core

target addresses for NEW_ADMIN,
NEW_GUARDIAN, and NEW_KEEPER are finalized

the operator understands that
the script grants real roles on-chain

the target network is explicitly confirmed

the active hardened core addresses are confirmed

evidence capture is prepared

No scenario execution is allowed
under unresolved uncertainty.

--------------------------------------------------

5. CANONICAL EXECUTION ORDER

Step 1
confirm compile-pass state

Step 2
confirm live core addresses

Step 3
confirm target role-holder addresses

Step 4
execute GovernanceMigrationScenario

Step 5
review on-chain verification result

Step 6
record transaction hashes

Step 7
record resulting role topology

Step 8
decide whether revoke phase
should ever be prepared separately

The script must not be followed
by immediate uncontrolled revoke actions.

--------------------------------------------------

6. EXPECTED SUCCESS CRITERIA

The scenario succeeds only if:

PHASE_A_GUARDIAN
PASS

PHASE_B_KEEPER
PASS

PHASE_C_ADMIN
PASS

and

GOVERNANCE MIGRATION SCENARIO RESULT
PASS

This means staged role grants
have been applied and verified correctly.

--------------------------------------------------

7. EXPLICIT NON-GOALS

This scenario does not:

remove legacy admin authority

remove legacy guardian authority

remove legacy keeper authority

finalize governance migration by itself

It is not a substitute for
controlled revoke planning.

It is a pre-destructive transition tool.

--------------------------------------------------

8. EXPLICIT PROHIBITIONS

The following are prohibited:

running the scenario on the wrong network

using ambiguous target addresses

treating grant success as final migration completion

performing immediate revoke actions
without a separate controlled decision

--------------------------------------------------

9. ACCEPTANCE CRITERIA

This runbook is accepted when:

script scope is explicit

required inputs are explicit

preconditions are explicit

success criteria are explicit

non-goals are explicit

destructive ambiguity is prohibited

--------------------------------------------------

10. CANONICAL STATUS

Governance migration scenario:
ready for controlled validation

Destructive governance migration:
still requires separate explicit approval
and revoke-stage planning
