# ADMIN MIGRATION PLAN — NEXUS CONTRACTS

Status: CANONICAL DRAFT
Standard: TOP-5 ELITE / audit-grade
Repo: nexus-contracts
Branch: law-phase1
Network: Arbitrum Sepolia

--------------------------------------------------

1. PURPOSE

This document defines the canonical
admin migration plan for the
NEXUS CONTRACTS on-chain layer.

It exists to migrate governance
authority from a single EOA
to a multisig-based structure.

This document is governance-critical.

Primary objective:

remove root admin concentration
without breaking protocol control.

--------------------------------------------------

2. CURRENT STATE

Current governance posture:

admin authority
single EOA

guardian authority
same EOA

keeper authority
same EOA

Core contracts affected:

NXUSDToken
OracleModule
VaultManager
LiquidationEngine

This is acceptable only as
temporary MVP live posture.

--------------------------------------------------

3. TARGET STATE

Target governance posture:

DEFAULT_ADMIN_ROLE
held by governance multisig

GUARDIAN_ROLE
held by guardian authority

KEEPER_ROLE
held by designated operators

MINTER_ROLE / BURNER_ROLE
remain contract-bound
to VaultManager

Target principle:

ADMIN != GUARDIAN != KEEPER

--------------------------------------------------

4. MIGRATION DESIGN PRINCIPLES

1. No control gap

At no point may the protocol
be left without valid admin control.

2. No destructive sequencing

Roles must never be revoked
before replacement authority
is confirmed on-chain.

3. Replayability

Every migration step must be
documented and verifiable.

4. Reversibility

If verification fails,
migration must stop before
destructive revocations.

5. Separation of powers

Guardian and keeper migration
must not be confused with
root admin migration.

--------------------------------------------------

5. CANONICAL MIGRATION ORDER

The migration order is fixed.

Step 1
prepare target multisig

Step 2
grant admin roles to multisig

Step 3
verify multisig role ownership

Step 4
verify protocol control continuity

Step 5
revoke admin roles from old EOA

Step 6
perform post-migration verification

Canonical sequence:

GRANT
VERIFY
REVOKE
VERIFY

This order is mandatory.

No alternative ordering is accepted.

--------------------------------------------------

6. PRE-MIGRATION CHECKLIST

Before any grant transaction:

- target multisig deployed
- signer set finalized
- threshold finalized
- target address validated

- chain/network confirmed
- contract addresses confirmed
- current role inventory confirmed
- emergency contacts aligned
- rollback operator identified
- verification method prepared

--------------------------------------------------

7. ROLE GRANT PHASE

In the grant phase,
the current admin EOA grants
DEFAULT_ADMIN_ROLE to the multisig
on each core contract.

Contracts in scope:

NXUSDToken
OracleModule

VaultManager
LiquidationEngine

No admin revocation occurs
during the grant phase.

The old admin must remain active
until verification succeeds.

--------------------------------------------------

8. GRANT VERIFICATION PHASE

After each grant transaction,
verify on-chain that the multisig
actually holds DEFAULT_ADMIN_ROLE.

Verification must confirm:

correct contract
correct role
correct holder

correct network
successful transaction finality

If any verification fails:

stop migration immediately

Do not revoke old admin rights.

--------------------------------------------------

9. CONTROL CONTINUITY CHECK

After grants are verified,
confirm that the multisig can
effectively act as admin.

This means verifying that:

the multisig is recognized on-chain

future admin actions remain possible

there is no address mismatch

there is no role identifier mismatch

there is no unexpected contract state

This phase exists to prevent
false-positive migration completion.

--------------------------------------------------

10. ROLE REVOKE PHASE

Only after successful grant
and successful verification
may the old EOA admin rights
be revoked.

Revocation scope:

DEFAULT_ADMIN_ROLE on NXUSDToken

DEFAULT_ADMIN_ROLE on OracleModule
DEFAULT_ADMIN_ROLE on VaultManager
DEFAULT_ADMIN_ROLE on LiquidationEngine

Revocations must be executed
only after the multisig is live
and confirmed as valid admin.

--------------------------------------------------

11. POST-MIGRATION VERIFICATION

After revocation, verify:

old EOA no longer holds
DEFAULT_ADMIN_ROLE

multisig still holds
DEFAULT_ADMIN_ROLE

guardian role state unchanged
unless intentionally migrated

keeper role state unchanged
unless intentionally migrated

protocol remains controllable
without interruption

--------------------------------------------------

12. EXPLICIT NON-GOALS

This migration does not by itself:

migrate guardian authority

migrate keeper authority

change token monetary logic

change oracle logic

change vault solvency logic

change liquidation economics

This plan covers admin migration only.

Other role migrations belong
to separate runbooks.

--------------------------------------------------

13. ROLLBACK LOGIC

Rollback is only valid
before old admin revocation
has completed.

If grant verification fails:

keep old admin active

do not continue migration

If role mismatch is detected:

pause migration sequence

reconfirm target multisig address

reconfirm role assignments

Only after root cause is resolved
may migration restart.

--------------------------------------------------

14. ACCEPTANCE CRITERIA

This migration is complete only if:

multisig holds DEFAULT_ADMIN_ROLE
on all intended contracts

old EOA no longer holds
DEFAULT_ADMIN_ROLE

all grant transactions are recorded

all verification evidence is recorded

all revoke transactions are recorded

post-migration control continuity
is confirmed

--------------------------------------------------

15. CANONICAL STATUS STATEMENT

This plan defines the mandatory
institutional path for transitioning
from EOA-rooted admin control
to multisig-rooted governance control.

Canonical rule:

GRANT -> VERIFY -> REVOKE -> VERIFY
