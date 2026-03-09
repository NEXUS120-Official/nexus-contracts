# REVOKE PHASE EXECUTION PLAN — NEXUS CONTRACTS

Status: CANONICAL DRAFT
Standard: TOP-5 ELITE / audit-grade / anti-drift / SSoT-ready
Repo: nexus-contracts
Branch: law-phase1
Network Scope: Arbitrum Sepolia

--------------------------------------------------

1. PURPOSE

This document defines the canonical
execution plan for the destructive
revoke phase of governance transition
in the NEXUS CONTRACTS layer.

This document is governance-critical.

Primary objective:

remove legacy EOA governance roles
only after replacement topology
has already been granted and verified.

This document governs destructive
governance actions.

--------------------------------------------------

2. CURRENT PRE-REVOKE POSTURE

The current posture after successful
governance migration scenario is:

new admin topology granted and verified

new guardian topology granted and verified

new keeper topology granted and verified

legacy EOA roles still remain active

This means the system is in a
dual-topology governance state.

This state is acceptable only
as a transitional governance posture,
not as a final institutional posture.

--------------------------------------------------

3. TARGET POST-REVOKE POSTURE

Target final posture:

DEFAULT_ADMIN_ROLE
held only by new governance authority

GUARDIAN_ROLE
held only by new guardian authority

KEEPER_ROLE
held only by new keeper authority

Legacy admin EOA must no longer hold:

VaultManager GUARDIAN_ROLE
LiquidationEngine GUARDIAN_ROLE
LiquidationEngine KEEPER_ROLE
DEFAULT_ADMIN_ROLE on all core contracts

--------------------------------------------------

4. CANONICAL REVOKE ORDER

The approved revoke order is:

Phase A
guardian revoke

Phase B
keeper revoke

Phase C
admin revoke

This order is mandatory.

Guardian must be separated before
root admin is removed.

Keeper must be separated before
root admin is removed.

Admin revoke is the final destructive step.

--------------------------------------------------

5. PHASE A — GUARDIAN REVOKE

Step 1
confirm new guardian still holds
GUARDIAN_ROLE on VaultManager

Step 2
confirm new guardian still holds
GUARDIAN_ROLE on LiquidationEngine

Step 3
revoke GUARDIAN_ROLE on VaultManager
from legacy admin EOA

Step 4
verify legacy admin no longer holds
GUARDIAN_ROLE on VaultManager

Step 5
revoke GUARDIAN_ROLE on LiquidationEngine
from legacy admin EOA

Step 6
verify legacy admin no longer holds
GUARDIAN_ROLE on LiquidationEngine

Step 7
confirm new guardian topology remains valid

If guardian continuity is uncertain,
the revoke sequence must stop.

--------------------------------------------------

6. PHASE B — KEEPER REVOKE

Step 1
confirm new keeper still holds
KEEPER_ROLE on LiquidationEngine

Step 2
optionally confirm keeper-path operability

Step 3
revoke KEEPER_ROLE on LiquidationEngine
from legacy admin EOA

Step 4
verify legacy admin no longer holds
KEEPER_ROLE on LiquidationEngine

Step 5
confirm new keeper topology remains valid

If liquidation continuity is uncertain,
the revoke sequence must stop.

--------------------------------------------------

7. PHASE C — ADMIN REVOKE

Step 1
confirm new admin still holds
DEFAULT_ADMIN_ROLE on NXUSDToken

Step 2
confirm new admin still holds
DEFAULT_ADMIN_ROLE on OracleModule

Step 3
confirm new admin still holds
DEFAULT_ADMIN_ROLE on VaultManager

Step 4
confirm new admin still holds
DEFAULT_ADMIN_ROLE on LiquidationEngine

Step 5
revoke DEFAULT_ADMIN_ROLE on NXUSDToken
from legacy admin EOA

Step 6
verify revoke on NXUSDToken

Step 7
revoke DEFAULT_ADMIN_ROLE on OracleModule
from legacy admin EOA

Step 8
verify revoke on OracleModule

Step 9
revoke DEFAULT_ADMIN_ROLE on VaultManager
from legacy admin EOA

Step 10
verify revoke on VaultManager

Step 11
revoke DEFAULT_ADMIN_ROLE on LiquidationEngine
from legacy admin EOA

Step 12
verify revoke on LiquidationEngine

Step 13
run final GovernanceVerify against
the new target topology only

--------------------------------------------------

8. STOP CONDITIONS

The revoke sequence must stop immediately if:

new guardian role is missing

new keeper role is missing

new admin role is missing

a revoke verification fails

Governance continuity becomes uncertain

network ambiguity exists

target contract ambiguity exists

Proceeding under uncertainty is forbidden.

--------------------------------------------------

9. REQUIRED POST-CHECKS

After each revoke:

verify old holder no longer has role

verify new holder still has role

record transaction hash

record operator identity

record contract and role affected

After final phase:

run GovernanceVerify against
new expected topology

update registry if topology is now canonical

record final checkpoint

--------------------------------------------------

10. EXPLICIT PROHIBITIONS

The following are prohibited:

revoke-first migration

batch destructive revokes without
phase-level verification

revoking admin before guardian and keeper
topology are stabilized

using destructive role mutation
on the wrong network

executing revoke sequence
without evidence capture

treating grant-only topology as final

--------------------------------------------------

11. CANONICAL STATUS

Current governance state:
dual-topology validated

Next institutional step:
controlled revoke-phase execution
