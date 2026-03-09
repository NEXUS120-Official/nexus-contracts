# GUARDIAN SEPARATION PLAN — NEXUS CONTRACTS

Status: CANONICAL DRAFT
Standard: TOP-5 ELITE / audit-grade / anti-drift / SSoT-ready
Repo: nexus-contracts
Branch: law-phase1
Network Scope: Arbitrum Sepolia

--------------------------------------------------

1. PURPOSE

This document defines the canonical
plan for separating guardian authority
from the current admin EOA in the
NEXUS CONTRACTS layer.

This document is governance-critical.

Primary objective:

establish a dedicated guardian authority
without introducing any loss of pause
capability during the transition.

This document is preparatory.
It does not itself execute migration.

--------------------------------------------------

2. CURRENT POSTURE

Current live posture:

VaultManager
GUARDIAN_ROLE
held by admin EOA

LiquidationEngine
GUARDIAN_ROLE
held by admin EOA

This means guardian and admin
remain merged in current active topology.

--------------------------------------------------

3. TARGET POSTURE

Target posture:

VaultManager
GUARDIAN_ROLE
held by dedicated guardian authority

LiquidationEngine
GUARDIAN_ROLE
held by dedicated guardian authority

Admin authority and guardian authority
must not remain permanently merged.

Preferred target models:

guardian multisig

or

dedicated emergency guardian address

The target holder must be explicitly identified
before any role mutation begins.

--------------------------------------------------

4. CORE GOVERNANCE PRINCIPLE

Pause continuity is mandatory.

At no point may guardian separation
leave the protocol without an active
and verifiable guardian authority.

Canonical sequence:

GRANT
VERIFY
REVOKE
VERIFY

--------------------------------------------------

5. CONTRACTS IN SCOPE

VaultManager

LiquidationEngine

Only contracts currently exposing
guardian capability are in scope
for this separation plan.

--------------------------------------------------

6. PRECONDITIONS

Before guardian separation:

target guardian address is finalized

target guardian address is verified

GovernanceVerify passes on current live core

role mutation helper scripts are compile-pass

incident escalation path is identified

the target network is explicitly confirmed

all active contract addresses are confirmed

If any of these conditions fail,
guardian separation must not proceed.

--------------------------------------------------

7. CANONICAL SEPARATION ORDER

Step 1
grant GUARDIAN_ROLE on VaultManager
to target guardian authority

Step 2
verify guardian role on VaultManager

Step 3
grant GUARDIAN_ROLE on LiquidationEngine
to target guardian authority

Step 4
verify guardian role on LiquidationEngine

Step 5
confirm pause continuity is preserved

Step 6
revoke GUARDIAN_ROLE on VaultManager
from admin EOA

Step 7
verify revoke on VaultManager

Step 8
revoke GUARDIAN_ROLE on LiquidationEngine
from admin EOA

Step 9
verify revoke on LiquidationEngine

Step 10
run GovernanceVerify with updated
expected guardian topology

--------------------------------------------------

8. REQUIRED POST-CHECKS

After grant phase:

confirm new guardian holds role
on both contracts

confirm no unexpected pause state
was introduced

confirm admin still retains control
where expected

After revoke phase:

confirm admin EOA no longer holds
GUARDIAN_ROLE on both contracts

confirm target guardian remains active

confirm governance topology matches
documented target state

--------------------------------------------------

9. ROLLBACK CONDITIONS

Rollback is valid before destructive
revoke sequence is complete.

If guardian grant verification fails:

do not proceed to revoke

If guardian continuity is uncertain:

do not proceed to revoke

If target guardian address is found
to be incorrect or unusable:

pause migration sequence
and re-validate all assumptions

Guardian separation must stop
under material uncertainty.

--------------------------------------------------

10. EXPLICIT PROHIBITIONS

The following are prohibited:

revoke guardian before replacement grant

separate guardian without verifying
target address correctness

merge guardian permanently with admin
as final governance posture

performing guardian mutation
on an unverified network

performing guardian mutation
without evidence capture

Proceeding without pause continuity
is forbidden.

--------------------------------------------------

11. ACCEPTANCE CRITERIA

This separation plan is accepted when:

current and target guardian topologies
are explicit

contract scope is explicit

preconditions are explicit

canonical order is explicit

rollback conditions are explicit

destructive sequencing is prohibited

--------------------------------------------------

12. CANONICAL STATUS

Current next institutional block:

guardian separation live-prep complete
admin multisig migration still pending
