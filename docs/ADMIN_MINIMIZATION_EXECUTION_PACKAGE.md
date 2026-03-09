# ADMIN MINIMIZATION EXECUTION PACKAGE — NEXUS CONTRACTS

Status: CANONICAL DRAFT
Standard: TOP-5 ELITE / audit-grade / anti-drift / SSoT-ready
Repo: nexus-contracts
Branch: law-phase1
Network Scope: Arbitrum Sepolia

--------------------------------------------------

1. PURPOSE

This document defines the canonical
execution package for minimizing
EOA-rooted governance authority
in the NEXUS CONTRACTS layer.

This document consolidates the previously
defined governance preparation plans.

This document is governance-critical.

Primary objective:

transition governance authority from
single-EOA posture to a distributed
institutional governance structure
without introducing operational risk.

This document defines execution order
and safety constraints.

--------------------------------------------------

2. GOVERNANCE MINIMIZATION OBJECTIVE

The current hardened core deployment
operates with admin authority held
by a single EOA.

This posture is operationally valid
for early hardened MVP stages,
but not aligned with long-term
institutional governance standards.

Admin minimization aims to reduce
single-key control exposure.

--------------------------------------------------

3. TARGET GOVERNANCE STRUCTURE

Target governance posture:

DEFAULT_ADMIN_ROLE
held by governance multisig

GUARDIAN_ROLE
held by dedicated guardian authority

KEEPER_ROLE
held by operational keeper address
or keeper operator set

Protocol-bound roles remain unchanged:

MINTER_ROLE
VaultManager

BURNER_ROLE
VaultManager

Operational contract relationships
must not be modified during this
governance transition.

--------------------------------------------------

4. EXECUTION PHASE MODEL

Governance minimization must occur
through controlled phases.

Phase A
guardian separation

Phase B
keeper separation

Phase C
admin migration to multisig

Phases must not be collapsed into
an uncontrolled single-step mutation.

Each phase must be verified before
proceeding to the next phase.

--------------------------------------------------

5. PHASE A — GUARDIAN SEPARATION

Execution order:

grant guardian role
to target guardian authority

verify guardian role on-chain

confirm pause continuity

revoke guardian role
from admin EOA

verify final guardian topology

Guardian separation must complete
successfully before keeper separation
or admin migration proceeds.

Pause continuity must remain intact
during the entire phase.

--------------------------------------------------

6. PHASE B — KEEPER SEPARATION

Execution order:

grant keeper role
to target keeper operator

verify keeper role

validate keeper operational path

revoke keeper role
from admin EOA

verify final keeper topology

Keeper separation must preserve
liquidation operability.

At no point may keeper rotation
leave the protocol without
a valid keeper operator.

--------------------------------------------------

7. PHASE C — ADMIN MIGRATION

Execution order:

grant admin role
to governance multisig

verify admin role
on multisig

confirm governance continuity

revoke admin role
from original EOA

verify final governance topology

run GovernanceVerify
against updated role expectations

--------------------------------------------------

8. GLOBAL PRECONDITIONS

Before executing any phase:

multisig address finalized

guardian authority finalized

keeper operator finalized

all contract addresses verified

GovernanceVerify passes on live deployment

helper scripts compile-pass

network explicitly confirmed

evidence capture method prepared

--------------------------------------------------

9. ROLLBACK POLICY

Rollback is possible during
grant verification phases.

Rollback is not possible once
destructive revoke operations
have completed.

Execution must stop if verification fails.

If governance continuity becomes uncertain:

pause migration sequence

revalidate assumptions

resume only when conditions are restored

--------------------------------------------------

10. EXPLICIT PROHIBITIONS

The following are prohibited:

revoking admin before multisig grant verification

revoking guardian before replacement grant

revoking keeper before replacement grant

performing role mutations
on the wrong network

performing migration without
evidence capture

performing migration under uncertainty

--------------------------------------------------

11. CANONICAL STATUS

Hardened core deployment:
completed and verified

Governance preparation:
completed

Next institutional milestone:

controlled multisig governance activation
