# ROLE ROTATION RUNBOOK — NEXUS CONTRACTS

Status: CANONICAL DRAFT
Standard: TOP-5 ELITE / audit-grade
Repo: nexus-contracts
Branch: law-phase1
Network: Arbitrum Sepolia

--------------------------------------------------

1. PURPOSE

This document defines the canonical
role rotation runbook for the
NEXUS CONTRACTS governance layer.

It exists to ensure that privileged
roles can be rotated safely without
breaking operational continuity.

Roles covered:

GUARDIAN_ROLE
KEEPER_ROLE
DEFAULT_ADMIN_ROLE (exceptional cases)

This document is operations-critical.

--------------------------------------------------

2. ROTATION OBJECTIVES

The role rotation process exists to:

reduce key stagnation risk

replace compromised keys

replace operational operators

upgrade operational security posture

maintain long-term protocol safety.

Rotation must never create
a temporary loss of authority.

Rotation must remain verifiable
through on-chain evidence.

--------------------------------------------------

3. ROLES IN SCOPE

Keeper role

Contract:
LiquidationEngine

Function:
execute liquidation operations
on unhealthy vaults.

Keeper role is operational
and must remain replaceable
without governance disruption.

Guardian role

Contracts:
VaultManager
LiquidationEngine

Function:
trigger emergency pause.

Admin role

Contracts:

NXUSDToken
OracleModule
VaultManager
LiquidationEngine

Admin rotation is exceptional
and normally occurs only during
governance migrations.

Routine operational rotation
should involve keeper and guardian
roles only.

--------------------------------------------------

4. ROTATION PRINCIPLES

1. No authority gap

At no point may the protocol
lose required operational authority.

2. Deterministic sequencing

Every rotation must follow
the canonical order:

GRANT
VERIFY
REVOKE
VERIFY

3. Verifiability

Every step must be
observable on-chain.

4. Minimal disruption

Rotation must avoid
interrupting normal protocol
operations whenever possible.

5. Incident awareness

If a role is compromised,
revocation priority increases
but verification still applies.

--------------------------------------------------

5. KEEPER ROTATION PROCEDURE

Step 1

Identify new keeper address.

Step 2

Verify operator identity.

Step 3

Grant KEEPER_ROLE
to new operator address.

Step 4

Verify role assignment
on-chain.

Step 5

Confirm that new keeper
can successfully execute
keeper-restricted operations.

Step 6

Revoke KEEPER_ROLE
from the previous operator.

Step 7

Confirm old keeper
no longer holds the role.

Keeper rotation sequence:

GRANT
VERIFY
REVOKE
VERIFY

--------------------------------------------------

6. GUARDIAN ROTATION PROCEDURE

Guardian rotation must be
executed carefully because
guardian authority controls
pause mechanisms.

Step 1

Identify new guardian authority.

Step 2

Verify guardian authority
operational readiness.

Step 3

Grant GUARDIAN_ROLE
to new authority address.

Step 4

Verify on-chain
guardian role assignment.

Step 5

Confirm guardian ability
to trigger pause in test environment
if applicable.

Step 6

Revoke GUARDIAN_ROLE
from previous holder.

Step 7

Confirm revocation success.

Guardian rotation sequence:

GRANT
VERIFY
REVOKE
VERIFY

--------------------------------------------------

7. EMERGENCY ROTATION

Emergency rotation occurs
when a key compromise
is suspected or confirmed.

Examples:

private key exposure

unauthorized transaction
originating from privileged key

malicious operator behavior

security breach indicators

Emergency rotation procedure:

1 pause protocol if required

2 grant replacement role

3 verify replacement authority

4 revoke compromised role

5 record incident evidence

--------------------------------------------------

8. EVIDENCE REQUIREMENTS

Every rotation must record:

timestamp
network
contract affected

old role holder
new role holder

grant transaction hash
revoke transaction hash

verification result

operator responsible

incident context if applicable

Evidence must be sufficient
to reconstruct the rotation
during an external audit.

--------------------------------------------------

9. ACCEPTANCE CRITERIA

Role rotation procedure
is accepted when:

grant procedure documented

verification procedure documented

revocation procedure documented

emergency rotation defined

evidence requirements defined

--------------------------------------------------

10. CANONICAL STATUS

This document defines the
institutional standard
for rotating operational roles
within the NEXUS CONTRACTS layer.

Canonical rotation rule:

GRANT -> VERIFY -> REVOKE -> VERIFY
