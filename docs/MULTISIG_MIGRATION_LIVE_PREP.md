# MULTISIG MIGRATION LIVE PREP — NEXUS CONTRACTS

Status: CANONICAL DRAFT
Standard: TOP-5 ELITE / audit-grade / anti-drift / SSoT-ready
Repo: nexus-contracts
Branch: law-phase1
Network Scope: Arbitrum Sepolia

--------------------------------------------------

1. PURPOSE

This document defines the canonical
live-preparation package for migrating
privileged governance authority from
single-EOA control to multisig control.

This document is governance-critical.

Primary objective:

prepare a safe and verifiable transition
from EOA-rooted control to a multisig-based
governance posture without introducing
control gaps or operational ambiguity.

This document is preparatory.
It does not itself perform migration.

--------------------------------------------------

2. CURRENT GOVERNANCE POSTURE

Current live posture:

admin
single EOA

guardian
single EOA

keeper
single EOA

This posture is operationally valid
for current hardened MVP stage,
but not sufficient for final
institutional governance posture.

--------------------------------------------------

3. TARGET GOVERNANCE POSTURE

Target posture:

DEFAULT_ADMIN_ROLE
held by governance multisig

GUARDIAN_ROLE
held by dedicated guardian authority
or guardian multisig

KEEPER_ROLE
held by designated operator addresses

Protocol contract-bound roles
must remain contract-bound where intended:

MINTER_ROLE
VaultManager

BURNER_ROLE
VaultManager

Canonical target principle:

ADMIN != GUARDIAN != KEEPER

--------------------------------------------------

4. MULTISIG REQUIREMENTS

The target governance multisig must have:

final signer set defined

final threshold defined

recovery assumptions documented

operational signer responsibilities documented

address verified before any role grant

Recommended baseline posture:

5 signers
3 threshold

A lower-security placeholder multisig
is not considered acceptable as
final institutional governance target.

--------------------------------------------------

5. ROLES TO BE MIGRATED

Primary migration scope:

NXUSDToken
DEFAULT_ADMIN_ROLE

OracleModule
DEFAULT_ADMIN_ROLE

VaultManager
DEFAULT_ADMIN_ROLE
GUARDIAN_ROLE

LiquidationEngine
DEFAULT_ADMIN_ROLE
GUARDIAN_ROLE
KEEPER_ROLE

Roles may migrate in phases,
but each phase must remain
operationally coherent.

--------------------------------------------------

6. CANONICAL MIGRATION PHASES

Phase A
admin migration to multisig

Phase B
guardian separation

Phase C
keeper separation and rotation

This phased model is preferred
over one-shot uncontrolled mutation.

--------------------------------------------------

7. ADMIN MIGRATION ORDER

The only approved admin migration order is:

grant admin role to multisig

verify admin role on multisig

verify control continuity

revoke admin role from old EOA

verify final admin topology

This order is mandatory.

No revoke-first sequence is permitted.

Admin migration must be performed
contract-by-contract or as a controlled
batch with explicit verification.

--------------------------------------------------

8. GUARDIAN SEPARATION ORDER

Guardian authority must not remain
permanently merged with admin authority.

Preferred order:

grant guardian role to guardian authority

verify guardian role live

revoke guardian role from admin EOA

verify final guardian topology

Guardian migration must preserve
pause capability throughout the sequence.

If pause continuity is uncertain,
guardian migration must stop.

--------------------------------------------------

9. KEEPER SEPARATION ORDER

Keeper migration must be handled
as an operational rotation.

Preferred order:

grant keeper role to new operator

verify keeper role live

optionally test controlled keeper path

revoke keeper role from old EOA

verify final keeper topology

Keeper rotation must not impair
liquidation operability.

--------------------------------------------------

10. MANDATORY LIVE PREP CHECKLIST

Before any live migration:

multisig address exists

multisig signer set is finalized

multisig threshold is finalized

all target contract addresses are confirmed

GovernanceVerify passes on current live core

RoleGrantScenario is compile-pass

RoleRevokeScenario is compile-pass

rollback authority is identified

incident escalation path is defined

registry update procedure is prepared

checkpoint template is prepared

--------------------------------------------------

11. EXPLICIT PROHIBITIONS

The following are prohibited:

migrating to an unverified multisig address

revoking admin before multisig grant verification

merging admin and guardian permanently
in the target topology

performing role changes without evidence capture

performing cross-network ambiguous operations

executing migration under unresolved uncertainty

Proceeding without clarity is forbidden.

--------------------------------------------------

12. ACCEPTANCE CRITERIA

This preparation package is accepted when:

target governance topology is explicit

multisig requirements are explicit

migration phases are explicit

live-prep checklist is explicit

destructive ordering is prohibited

the package is sufficient to support
a future controlled live migration

--------------------------------------------------

13. CANONICAL STATUS

Current active core:
hardened live verified

Current next institutional block:
admin minimization and multisig migration live-prep
