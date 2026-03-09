# HARDENED CORE REDEPLOY PLAN — NEXUS CONTRACTS

Status: CANONICAL DRAFT
Standard: TOP-5 ELITE / audit-grade / anti-drift
Repo: nexus-contracts
Branch: law-phase1
Network: Arbitrum Sepolia

--------------------------------------------------

1. PURPOSE

This document defines the canonical
redeploy plan required to align
the live core deployment with the
current hardened repository state.

This document is deployment-critical.

Primary objective:

replace the current live core
with a governance-hardened core
that exposes emergency controls.

--------------------------------------------------

2. VERIFIED FINDING

GovernanceVerify v1.1 established:

ROLE CHECK RESULT:
PASS

CAPABILITY CHECK RESULT:
FAIL

Confirmed missing on current live core:

VaultManager
- GUARDIAN_ROLE()
- paused()

LiquidationEngine
- GUARDIAN_ROLE()
- paused()

This demonstrates that the
current Arbitrum Sepolia core deployment
does not expose the emergency-hardening
capability surface expected by
the repository, tests and docs.

Canonical interpretation:

repo state != current live core state

--------------------------------------------------

3. REDEPLOY OBJECTIVE

The redeploy must produce
a new core deployment where:

VaultManager exposes
GUARDIAN_ROLE()
paused()
pause()
unpause()

LiquidationEngine exposes
GUARDIAN_ROLE()
paused()
pause()
unpause()

The redeployed core must also preserve:

correct NXUSD admin wiring
correct mint authority wiring
correct burn authority wiring
correct oracle admin wiring
correct keeper authority wiring

Emergency hardening must be live,
not only present in source code.

--------------------------------------------------

4. CANONICAL REDEPLOY ORDER

Step 1
confirm hardened source state

Step 2
confirm tests green

Step 3
deploy hardened core stack

Step 4
run post-deploy verify

Step 5
run GovernanceVerify v1.1

Step 6
update deployment registry

Step 7
tag hardened live deployment

Canonical rule:

DEPLOY
VERIFY
REGISTER
TAG

No hardened deployment is accepted
without governance capability verification.

--------------------------------------------------

5. ACCEPTANCE CRITERIA

The redeploy is accepted only if:

GovernanceVerify role checks pass

GovernanceVerify capability checks pass

VaultManager guardian capability is live

VaultManager pause capability is live

LiquidationEngine guardian capability is live

LiquidationEngine pause capability is live

deployment registry is updated

runbooks remain consistent

new addresses are recorded
as canonical active core addresses

--------------------------------------------------

6. CANONICAL STATUS

Current live core:
not governance-hardened

Next required milestone:
hardened core redeploy and live verification
