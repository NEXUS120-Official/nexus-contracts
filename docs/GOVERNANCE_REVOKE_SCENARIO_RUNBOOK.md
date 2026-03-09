# GOVERNANCE REVOKE SCENARIO RUNBOOK — NEXUS CONTRACTS

Status: CANONICAL DRAFT
Standard: TOP-5 ELITE / audit-grade / anti-drift / SSoT-ready
Repo: nexus-contracts
Branch: law-phase1
Network Scope: Arbitrum Sepolia

--------------------------------------------------

1. PURPOSE

This runbook defines the canonical
usage procedure for executing the
GovernanceRevokeScenario script
in the NEXUS CONTRACTS layer.

This document is governance-critical.

Primary objective:

remove legacy EOA governance roles
only after replacement topology
has already been granted and verified.

This runbook governs destructive
governance execution.

--------------------------------------------------

2. SCRIPT SCOPE

The script in scope is:

script/GovernanceRevokeScenario.s.sol

Its purpose is to remove
legacy governance authority
in the approved canonical order:

guardian revoke
keeper revoke
admin revoke

The script performs destructive changes.

It must be treated as a controlled
governance transition tool,
not a routine helper script.

--------------------------------------------------

3. REQUIRED INPUTS

Required env vars:

PRIVATE_KEY

NXUSD_TOKEN
ORACLE_MODULE
VAULT_MANAGER
LIQUIDATION_ENGINE

OLD_ADMIN
NEW_ADMIN
NEW_GUARDIAN
NEW_KEEPER

All values must be explicitly verified
before execution begins.

The script must be executed only
against the intended hardened live core.

--------------------------------------------------

4. PRECONDITIONS

Before running the revoke scenario:

Governance migration scenario has passed

GovernanceVerify passes
against the new target topology

OLD_ADMIN is confirmed correct

NEW_ADMIN is confirmed correct

NEW_GUARDIAN is confirmed correct

NEW_KEEPER is confirmed correct

the target network is explicitly confirmed

evidence capture is prepared

No destructive revoke execution
is allowed under unresolved uncertainty.

--------------------------------------------------

5. CANONICAL EXECUTION ORDER

Step 1
confirm compile-pass state

Step 2
confirm active hardened core addresses

Step 3
confirm all role-holder addresses

Step 4
execute GovernanceRevokeScenario

Step 5
review phase-by-phase result

Step 6
run GovernanceVerify
against the final intended topology

Step 7
record transaction hashes

Step 8
record final governance topology

Step 9
update canonical registry or checkpoint
if the revoke phase is now final

--------------------------------------------------

6. EXPECTED SUCCESS CRITERIA

The revoke scenario succeeds only if:

PHASE_A_GUARDIAN_REVOKE
PASS

PHASE_B_KEEPER_REVOKE
PASS

PHASE_C_ADMIN_REVOKE
PASS

FINAL_VERIFY
PASS

and

GOVERNANCE REVOKE SCENARIO RESULT
PASS

This means legacy EOA governance roles
have been removed successfully
while replacement topology remains intact.

--------------------------------------------------

7. EXPLICIT PROHIBITIONS

The following are prohibited:

running the revoke scenario
before grant topology is verified

running the revoke scenario
on the wrong network

using ambiguous OLD_ADMIN or NEW_* values

treating partial phase success
as final migration completion

executing destructive revokes
without evidence capture

--------------------------------------------------

8. CANONICAL STATUS

Governance revoke scenario:
ready for controlled destructive validation

Final governance cutover:
requires explicit execution decision
