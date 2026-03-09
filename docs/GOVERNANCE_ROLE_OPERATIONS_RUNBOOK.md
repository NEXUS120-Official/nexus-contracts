# GOVERNANCE ROLE OPERATIONS RUNBOOK — NEXUS CONTRACTS

Status: CANONICAL DRAFT
Standard: TOP-5 ELITE / audit-grade / anti-drift
Repo: nexus-contracts
Branch: law-phase1
Network Scope: Arbitrum Sepolia

--------------------------------------------------

1. PURPOSE

This document defines the canonical
operational procedure for granting
and revoking privileged roles
in the NEXUS CONTRACTS layer.

This document is governance-critical.

Primary objective:

ensure that role changes are executed
in a deterministic, verifiable,
and non-destructive sequence.

This runbook applies to the use of:

script/RoleGrantScenario.s.sol
script/RoleRevokeScenario.s.sol
script/GovernanceVerify.s.sol

--------------------------------------------------

2. ROLES IN SCOPE

DEFAULT_ADMIN_ROLE

GUARDIAN_ROLE

KEEPER_ROLE

MINTER_ROLE

BURNER_ROLE

Not every role applies to every contract.
Role support must be verified before mutation.

--------------------------------------------------

3. CANONICAL OPERATION ORDER

The only approved role transition order is:

GRANT
VERIFY
REVOKE
VERIFY

This order is mandatory.

No destructive revoke-first sequence
is permitted in routine governance operations.

--------------------------------------------------

4. GRANT PROCEDURE

Step 1
identify target contract

Step 2
identify role kind

Step 3
identify target grantee

Step 4
confirm role support on contract

Step 5
execute RoleGrantScenario

Step 6
confirm post-grant verification passes

Step 7
record transaction hash and operator identity

No revoke may follow until
grant verification is successful.

--------------------------------------------------

5. REVOKE PROCEDURE

Step 1
confirm replacement authority already exists
if continuity is required

Step 2
identify target contract

Step 3
identify role kind

Step 4
identify account to revoke

Step 5
execute RoleRevokeScenario

Step 6
confirm post-revoke verification passes

Step 7
record transaction hash and operator identity

Revoke operations must be treated
as destructive governance actions.

--------------------------------------------------

6. MANDATORY POST-CHECKS

After any governance role mutation:

run targeted verification of the changed role

run GovernanceVerify when the change
affects active governance topology

confirm no unintended role loss occurred

confirm the protocol remains controllable

--------------------------------------------------

7. EXPLICIT PROHIBITIONS

The following are prohibited:

revoke before replacement grant

mutating unsupported role surfaces

combining unrelated governance actions
in a single uncontrolled sequence

changing roles without recording evidence

using role scripts on the wrong network

using role scripts without confirming
the correct target contract address

Proceeding under uncertainty is not allowed.

--------------------------------------------------

8. ACCEPTANCE CRITERIA

This runbook is accepted when:

grant order is explicit

revoke order is explicit

verification requirements are explicit

destructive sequencing is prohibited

the governance helper scripts are referenced

the procedure is replayable and audit-usable

--------------------------------------------------

9. CANONICAL STATUS

This document defines the approved
operational standard for privileged
role mutation in the NEXUS CONTRACTS layer.
