# HARDENED CORE LIVE RUNBOOK — NEXUS CONTRACTS

Status: CANONICAL DRAFT
Standard: TOP-5 ELITE / audit-grade / anti-drift
Repo: nexus-contracts
Branch: law-phase1
Network: Arbitrum Sepolia

--------------------------------------------------

1. PURPOSE

This runbook defines the canonical
live deployment procedure for the
hardened core stack on Arbitrum Sepolia.

This document is execution-critical.

Primary objective:

deploy a live core stack that is
governance-capable and emergency-hardened.

--------------------------------------------------

2. PRECONDITION

The current live core deployment
has been verified as lacking
guardian and pause capability
on VaultManager and LiquidationEngine.

Therefore, a hardened redeploy is required.

This runbook applies only to the
new hardened core deployment path.

--------------------------------------------------

3. REQUIRED INPUTS

The deployment requires these env vars:

PRIVATE_KEY
ADMIN
KEEPER
GUARDIAN
COLLATERAL_TOKEN
ORACLE_FEED

ORACLE_MAX_DELAY
VAULT_MAX_DELAY
MIN_COLLATERAL_RATIO_BPS
LIQUIDATION_RATIO_BPS
CLOSE_FACTOR_BPS

The deployment must be executed
against Arbitrum Sepolia only.

Canonical RPC:

https://sepolia-rollup.arbitrum.io/rpc

The RPC endpoint must be explicit
during execution to avoid network drift.

--------------------------------------------------

4. CANONICAL EXECUTION ORDER

Step 1
confirm working tree state

Step 2
confirm script compiles

Step 3
confirm env values

Step 4
execute DeployCoreHardened.s.sol

Step 5
record deployed addresses

Step 6
run post-deploy verify

Step 7
run GovernanceVerify v1.1

Step 8
update deployment registry

Step 9
record canonical checkpoint

Canonical rule:

DEPLOY
VERIFY
REGISTER
CHECKPOINT

No hardened deployment is valid
without capability verification.

--------------------------------------------------

5. PRE-DEPLOY CHECKS

Before deployment confirm:

forge build --skip test passes

DeployCoreHardened.s.sol is current

GovernanceVerify.s.sol is current

oracle feed address is correct

collateral token address is correct

admin address is correct

keeper address is correct

guardian address is correct

numeric parameters match canonical values

If any of these checks fail,
deployment must not proceed.

--------------------------------------------------

6. DEPLOY COMMAND SHAPE

Canonical execution shape:

forge script script/DeployCoreHardened.s.sol:DeployCoreHardenedScript \
  --rpc-url https://sepolia-rollup.arbitrum.io/rpc \
  --broadcast

The deployment must use the explicit
hardened script, not the legacy script.

--------------------------------------------------

7. REQUIRED DEPLOY OUTPUTS

The execution must produce:

NXUSDToken address
OracleModule address
VaultManager address
LiquidationEngine address

Admin address
Keeper address
Guardian address

POST-DEPLOY ASSERT : PASS

If the post-deploy assertions fail,
the deployment is not considered valid,
even if transactions were broadcast.

--------------------------------------------------

8. POST-DEPLOY GOVERNANCE VERIFY

Immediately after deployment,
run GovernanceVerify v1.1
against the newly deployed addresses.

Acceptance expectation:

ROLE CHECK RESULT      : PASS
CAPABILITY CHECK RESULT: PASS
GOVERNANCE VERIFY RESULT: PASS

This is the canonical proof that
the hardened live deployment is aligned
with the hardened repository state.

--------------------------------------------------

9. REGISTRY UPDATE REQUIREMENT

After successful verify,
the new hardened addresses must be recorded
in the canonical deployment registry.

The registry entry must clearly distinguish:

legacy core deployment

hardened core deployment

No old address may remain marked
as canonical active core if the
new hardened deployment supersedes it.

--------------------------------------------------

10. ACCEPTANCE CRITERIA

The hardened live deployment is accepted only if:

deploy script broadcast succeeds

post-deploy assertions pass

GovernanceVerify role checks pass

GovernanceVerify capability checks pass

registry is updated

checkpoint is recorded

--------------------------------------------------

11. CANONICAL STATUS

This runbook defines the only
approved path for establishing
a hardened live core deployment
on Arbitrum Sepolia.
