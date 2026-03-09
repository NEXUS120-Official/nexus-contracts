# CHECKPOINT CANONICO — NEXUS CONTRACTS HARDENED CORE

Date: 2026-03-09
Standard: TOP-5 ELITE / audit-grade / anti-drift / SSoT-ready
Repo: nexus-contracts
Branch: law-phase1
Network: Arbitrum Sepolia

--------------------------------------------------

0. EXECUTIVE STATUS

NEXUS CONTRACTS has completed
the hardened core redeploy cycle
on Arbitrum Sepolia.

The current active live core is now:

governance-capable
guardian-enabled
pause-enabled
post-deploy asserted
governance-verified

Legacy core addresses are now
considered superseded for canonical
active-core purposes.

The hardened core deployment is now
the canonical live deployment track.

--------------------------------------------------

1. ACTIVE HARDENED CORE ADDRESSES

NXUSDToken
0x515844Dd91956C749e33521B4f171dac4e04FE07

OracleModule
0xa1BD5AF1174140caB018e46eBCFEf1d005c3df84

VaultManager
0xF09AAD220C6c4d805cF6cE5561B546f51ADFBb03

LiquidationEngine
0xF333d9ae2D70305758E714ecBeA938e9377a9f9D

Admin
0xB4518cebFf8a92A8514f90F21B86e7Cb987F4ab6

Keeper
0xB4518cebFf8a92A8514f90F21B86e7Cb987F4ab6

Guardian
0xB4518cebFf8a92A8514f90F21B86e7Cb987F4ab6

--------------------------------------------------

2. DEPLOYMENT PARAMETERS

Collateral Token
0x980B62Da83eFf3D4576C647993b0c1D7faf17c73

Oracle Feed
0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165

oracleMaxDelay
3600

vaultMaxDelay
3600

minCollateralRatioBps
15000

liquidationRatioBps
13000

closeFactorBps
5000

--------------------------------------------------

3. HARDENED CAPABILITY STATUS

VaultManager

GUARDIAN_ROLE()
PASS

paused()
PASS

LiquidationEngine

GUARDIAN_ROLE()
PASS

paused()
PASS

This confirms that emergency
governance capability is live,
not only present in repository code.

--------------------------------------------------

4. GOVERNANCE VERIFY STATUS

GovernanceVerify v1.1 result:

ROLE CHECK RESULT
PASS

CAPABILITY CHECK RESULT
PASS

GOVERNANCE VERIFY RESULT
PASS

Verified role surfaces include:

NXUSDToken
DEFAULT_ADMIN_ROLE
MINTER_ROLE
BURNER_ROLE

OracleModule
DEFAULT_ADMIN_ROLE

VaultManager
DEFAULT_ADMIN_ROLE
GUARDIAN_ROLE

LiquidationEngine
DEFAULT_ADMIN_ROLE
GUARDIAN_ROLE
KEEPER_ROLE

--------------------------------------------------

5. POST-DEPLOY ASSERT STATUS

DeployCoreHardened.s.sol
post-deploy assertions
PASS

Vault paused
false

LiquidationEngine paused
false

This confirms that the hardened
core was deployed in a clean,
active, non-paused state.

--------------------------------------------------

6. GOVERNANCE OPERATIONS TOOLING STATUS

GovernanceVerify.s.sol
READY

DeployCoreHardened.s.sol
READY

RoleGrantScenario.s.sol
READY

RoleRevokeScenario.s.sol
READY

GOVERNANCE_ROLE_OPERATIONS_RUNBOOK.md
READY

This means the protocol now has
an executable governance operations layer,
not only passive documentation.

--------------------------------------------------

7. REGISTRY STATUS

Canonical active registry:

deployments/arbitrum-sepolia-core-hardened.json

Superseded legacy registry:

deployments/arbitrum-sepolia-core.json

This separation preserves
historical audit traceability
without ambiguity on active state.

--------------------------------------------------

8. INSTITUTIONAL ASSESSMENT

NEXUS CONTRACTS is no longer only
a live MVP with basic operational control.

It is now a live hardened MVP with:

verified governance surface
verified emergency controls
verified deployment assertions
role mutation tooling
runbook-backed governance procedures

This is a materially stronger posture
for auditability, replayability,
and controlled governance evolution.

--------------------------------------------------

9. OPEN ITEMS REMAINING

Admin remains concentrated on one EOA

Keeper remains concentrated on one EOA

Guardian remains concentrated on one EOA

Multisig migration is not yet live

Treasury routing is not yet implemented

Final mainnet constitutional posture
is not yet reached

--------------------------------------------------

10. CANONICAL STATUS STATEMENT

Current canonical active core:
hardened core live verified

Current canonical next block:
admin minimization and multisig migration
