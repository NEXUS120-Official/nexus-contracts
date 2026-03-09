# KEEPER SEPARATION PLAN — NEXUS CONTRACTS

Status: CANONICAL DRAFT
Standard: TOP-5 ELITE / audit-grade / anti-drift / SSoT-ready
Repo: nexus-contracts
Branch: law-phase1
Network Scope: Arbitrum Sepolia

--------------------------------------------------

1. PURPOSE

This document defines the canonical
plan for separating keeper authority
from the current admin EOA in the
NEXUS CONTRACTS layer.

This document is governance-critical.

Primary objective:

establish a dedicated keeper topology
without impairing liquidation operability
during or after the transition.

This document is preparatory.
It does not itself execute migration.

--------------------------------------------------

2. CURRENT POSTURE

Current live posture:

LiquidationEngine
KEEPER_ROLE
held by admin EOA

This means keeper and admin
remain merged in current active topology.

This is acceptable for current hardened MVP stage,
but not for final institutional operations posture.

--------------------------------------------------

3. TARGET POSTURE

Target posture:

LiquidationEngine
KEEPER_ROLE
held by dedicated keeper operator address
or keeper operator set

Admin authority and keeper authority
must not remain permanently merged.

Keeper authority should be revocable
without changing admin governance.

Preferred target models:

single dedicated keeper operator

or

small keeper operator set
with explicit revocation capability

The target keeper holder or holders
must be explicitly identified
before any role mutation begins.

--------------------------------------------------

4. CORE GOVERNANCE PRINCIPLE

Liquidation continuity is mandatory.

At no point may keeper separation
leave the protocol unable to execute
keeper-driven liquidation operations
if liquidation conditions arise.

Canonical sequence:

GRANT
VERIFY
REVOKE
VERIFY

--------------------------------------------------

5. CONTRACT IN SCOPE

LiquidationEngine

Only contracts currently exposing
keeper capability are in scope
for this separation plan.

--------------------------------------------------

6. PRECONDITIONS

Before keeper separation:

target keeper address is finalized

target keeper address is verified

GovernanceVerify passes on current live core

role mutation helper scripts are compile-pass

liquidation operational owner is identified

the target network is explicitly confirmed

the active LiquidationEngine address is confirmed

the operator understands keeper responsibilities

If any of these conditions fail,
keeper separation must not proceed.

--------------------------------------------------

7. CANONICAL SEPARATION ORDER

Step 1
grant KEEPER_ROLE on LiquidationEngine
to target keeper operator

Step 2
verify keeper role on LiquidationEngine

Step 3
optionally execute controlled keeper-path validation

Step 4
confirm liquidation continuity is preserved

Step 5
revoke KEEPER_ROLE on LiquidationEngine
from admin EOA

Step 6
verify revoke on LiquidationEngine

Step 7
run GovernanceVerify with updated
expected keeper topology

--------------------------------------------------

8. REQUIRED POST-CHECKS

After grant phase:

confirm new keeper holds role

confirm no unexpected pause state
was introduced

confirm admin still retains control
where expected

confirm keeper role is not missing
from active topology

After revoke phase:

confirm admin EOA no longer holds
KEEPER_ROLE

confirm target keeper remains active

confirm final topology matches
documented target state

--------------------------------------------------

9. ROLLBACK CONDITIONS

Rollback is valid before destructive
revoke sequence is complete.

If keeper grant verification fails:

do not proceed to revoke

If liquidation continuity is uncertain:

do not proceed to revoke

If target keeper address is found
to be incorrect or unusable:

pause migration sequence
and re-validate all assumptions

Keeper separation must stop
under material uncertainty.

--------------------------------------------------

10. EXPLICIT PROHIBITIONS

The following are prohibited:

revoke keeper before replacement grant

separate keeper without verifying
target address correctness

keep keeper permanently merged with admin
as final operational posture

performing keeper mutation
on an unverified network

performing keeper mutation
without evidence capture

Proceeding without liquidation continuity
is forbidden.

--------------------------------------------------

11. ACCEPTANCE CRITERIA

This separation plan is accepted when:

current and target keeper topologies
are explicit

contract scope is explicit

preconditions are explicit

canonical order is explicit

rollback conditions are explicit

destructive sequencing is prohibited

--------------------------------------------------

12. CANONICAL STATUS

Current next institutional block:

keeper separation live-prep complete
admin multisig migration still pending
