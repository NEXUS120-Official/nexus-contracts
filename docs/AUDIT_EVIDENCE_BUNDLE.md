# AUDIT EVIDENCE BUNDLE — NEXUS CONTRACTS

Status: CANONICAL DRAFT
Standard: TOP-5 ELITE / audit-grade
Repo: nexus-contracts
Branch: law-phase1
Network: Arbitrum Sepolia

--------------------------------------------------

1. PURPOSE

This document defines the canonical
audit evidence bundle for the
NEXUS CONTRACTS on-chain layer.

It exists to specify which materials
must be collected, organized,
and delivered to an external reviewer.

This document is audit-critical.

--------------------------------------------------

2. AUDIT BUNDLE OBJECTIVES

The audit evidence bundle exists to:

demonstrate contract scope

demonstrate deployment integrity

demonstrate governance controls

demonstrate operational replayability

demonstrate test coverage

demonstrate live verification posture

demonstrate incident readiness

The bundle must be structured,
replayable, and reviewer-usable.

--------------------------------------------------

3. CORE CONTRACT SCOPE

Contracts in current bundle scope:

NXUSDToken
OracleModule
VaultManager
LiquidationEngine

These contracts represent the
current core live MVP stack
for the NEXUS CONTRACTS layer.

Any future contract additions
must be appended explicitly.

--------------------------------------------------

4. REQUIRED EVIDENCE CATEGORIES

The canonical evidence categories are:

A. source code evidence
B. test evidence
C. deployment evidence
D. live verification evidence
E. governance evidence
F. emergency operations evidence
G. registry evidence
H. git traceability evidence
I. known-risk disclosure

--------------------------------------------------

5. SOURCE CODE EVIDENCE

The bundle must identify:

contract file names

contract purposes

current architectural boundaries

contract-to-contract relationships

privileged role surfaces

pause-sensitive surfaces

The code scope delivered to reviewers
must match the deployment scope.

Minimum source code references:

src/NXUSDToken.sol
src/OracleModule.sol
src/VaultManager.sol
src/LiquidationEngine.sol

If mocks are included for context,
they must be clearly labeled
as non-production support artifacts.

--------------------------------------------------

6. TEST EVIDENCE

The bundle must include evidence
that the current canonical suite passes.

Current suite expectation:

32 / 32 PASS

Test evidence should include:

test file inventory

test purpose summary

forge test pass result

governance hardening test evidence

pause control test evidence

Where possible, include:

test command used
test environment versioning
relevant output snapshot

Test evidence must distinguish
unit coverage from live validation.

--------------------------------------------------

7. DEPLOYMENT EVIDENCE

The bundle must include:

deployment scripts used

deployment registries

network used

deployed contract addresses

deployer identity class

wiring assumptions

post-deploy verification status

Canonical deployment registry references:

deployments/arbitrum-sepolia-smoke.json
deployments/arbitrum-sepolia-core.json

Canonical deployment script references:

script/DeploySmokeStack.s.sol
script/DeployCore.s.sol
script/PostDeployVerify.s.sol
script/CoreLiveScenario.s.sol

--------------------------------------------------

8. LIVE VERIFICATION EVIDENCE

The bundle must document:

smoke deploy live PASS

smoke scenario live PASS

core deploy live PASS

post-deploy verify live PASS

core live scenario PASS

This section must include
network-specific deployed addresses
and scenario outcome summaries.

If block explorers or external
verification references are used,
they must match the exact addresses
stored in canonical registries.

Live evidence must be consistent
with the runbooks and git history.

--------------------------------------------------

9. GOVERNANCE EVIDENCE

The bundle must include:

docs/ROLE_MATRIX.md
docs/ADMIN_MIGRATION_PLAN.md
docs/EMERGENCY_OPERATIONS_RUNBOOK.md
docs/ROLE_ROTATION_RUNBOOK.md

These documents define the
current governance hardening posture
for the on-chain layer.

They must be included as
governance control evidence.

--------------------------------------------------

10. EMERGENCY OPERATIONS EVIDENCE

The bundle must show that
emergency pause capability exists
and is documented.

Required evidence includes:

pause-enabled contracts inventory

guardian authority model

admin recovery model

pause test coverage

incident handling logic

unpause conditions

This evidence demonstrates that
the protocol is not only deployable,
but also operationally containable
under adverse conditions.

--------------------------------------------------

11. REGISTRY EVIDENCE

Registry evidence must include:

deployment registries

live address records

canonical tags

state references used
for replayability and audit memory

At minimum, the reviewer must be able
to map code scope to deployed scope
and deployed scope to runbook scope.

--------------------------------------------------

12. GIT TRACEABILITY EVIDENCE

The bundle must include
canonical commit references
for the most relevant phase changes.

Examples include:

deploy script introduction

runbook introduction

audit manifest introduction

guardian hardening introduction

Relevant tags should also be listed.

Examples:

RC_CONTRACTS_NXUSD_V1_LOCKED
RC_CONTRACTS_ORACLE_V1_LOCKED
RC_CONTRACTS_VAULT_V0_LOCKED
RC_CONTRACTS_LIQUIDATION_V0_LOCKED
RC_CONTRACTS_SMOKE_ARBITRUM_SEPOLIA_LIVE
RC_CONTRACTS_CORE_ARBITRUM_SEPOLIA_LIVE
RC_CONTRACTS_CORE_SCENARIO_ARBITRUM_SEPOLIA_LIVE

--------------------------------------------------

13. KNOWN-RISK DISCLOSURE

The bundle must explicitly disclose
open risks still present at this phase.

At minimum disclose:

admin concentration risk

guardian concentration risk

keeper concentration risk

absence of multisig live migration

treasury routing not yet implemented

liquidation fee split not finalized

mainnet operational governance
not yet complete

A strong audit bundle does not hide
known limitations. It records them.

--------------------------------------------------

14. REVIEWER READINESS CHECK

The bundle is reviewer-ready only if:

scope is explicit

evidence categories are complete

addresses are consistent

runbooks are present

governance controls are documented

tests are reproducible

known risks are disclosed

A reviewer must be able to answer:

what is deployed

what is tested

what is live

who controls what

what happens in emergency

what remains unfinished

--------------------------------------------------

15. ACCEPTANCE CRITERIA

This document is accepted when:

all core evidence categories
are explicitly enumerated

deployment evidence is identified

test evidence is identified

governance evidence is identified

known-risk disclosure is included

reviewer usability is preserved

--------------------------------------------------

16. CANONICAL STATUS

This document defines the
minimum institutional structure
for packaging NEXUS CONTRACTS
evidence for external audit review.

Core rule:

if an auditor cannot reconstruct it,
the bundle is incomplete.
