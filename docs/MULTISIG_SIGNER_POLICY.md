# MULTISIG SIGNER POLICY — NEXUS CONTRACTS

Status: CANONICAL DRAFT
Standard: TOP-5 ELITE / audit-grade / anti-drift / SSoT-ready
Repo: nexus-contracts
Branch: law-phase1
Network Scope: Arbitrum Sepolia

--------------------------------------------------

1. PURPOSE

This document defines the canonical
signer policy for the governance multisig
intended to control privileged admin roles
in the NEXUS CONTRACTS layer.

This document is governance-critical.

Primary objective:

define a signer structure that is
operationally resilient, institutionally
credible, and compatible with controlled
governance evolution.

This document defines policy,
not on-chain execution.

--------------------------------------------------

2. POLICY OBJECTIVE

The multisig signer set must reduce:

single-key compromise risk

single-operator control risk

governance liveness fragility

institutional concentration risk

The multisig must improve security
without making governance inoperable.

--------------------------------------------------

3. TARGET BASELINE CONFIGURATION

Recommended target baseline:

5 signers
3 signature threshold

This means:

no single signer can control governance

no two signers can unilaterally control governance

the signer set can tolerate one unavailable signer
without losing normal operability

A 5-of-3 style posture is preferred
for current institutional target state.

Alternative signer counts may be used
only with explicit justification.

--------------------------------------------------

4. SIGNER CLASS MODEL

The signer set should not be composed
of equivalent undifferentiated holders.

Preferred signer classes:

core protocol authority

operations authority

security authority

backup authority A

backup authority B

This model improves institutional balance.

It reduces the probability that
all keys fail under the same
operational or organizational condition.

--------------------------------------------------

5. SIGNER RESPONSIBILITY PRINCIPLES

Every signer must understand:

what the multisig controls

what the signer is authorizing

what the emergency implications are

what transactions require escalation

what actions must not be signed casually

A signer is not a passive placeholder.

A signer is an active governance control point.

--------------------------------------------------

6. SIGNER OPERATIONAL REQUIREMENTS

Each signer should satisfy these minimum requirements:

secure wallet custody

independent device hygiene

independent secret handling

clear communication path

availability expectations defined

role awareness confirmed

Signers should not all depend
on the same single device,
single machine, or single operator workflow.

--------------------------------------------------

7. SIGNER APPROVAL STANDARDS

Before signing governance actions,
signers should confirm:

target contract is correct

target network is correct

role effect is understood

transaction intent is documented

post-execution consequence is understood

No signer should approve
blind or ambiguous transactions.

--------------------------------------------------

8. SIGNER ROTATION POLICY

Signer rotation must be possible
without collapsing governance continuity.

Rotation triggers may include:

key compromise suspicion

loss of device custody

loss of signer availability

institutional role change

security posture upgrade

Signer rotation must itself follow
a controlled governance procedure
with explicit evidence and verification.

--------------------------------------------------

9. LOST KEY POLICY

If a signer loses control of a key,
the event must be treated as a
security-relevant governance event.

Minimum response:

classify severity

assess whether threshold safety remains intact

prepare signer replacement

document the incident

If compromise is suspected,
the incident must not be treated
as routine signer turnover.

--------------------------------------------------

10. EXPLICIT PROHIBITIONS

The following are prohibited:

all signer keys controlled by one person

all signer keys stored in one place

signers approving unclear transactions

using weak placeholder signer sets
as final governance posture

keeping signer policy undocumented

--------------------------------------------------

11. ACCEPTANCE CRITERIA

This signer policy is accepted when:

baseline signer count is defined

threshold is defined

signer classes are defined

responsibility standards are defined

rotation logic is acknowledged

explicit prohibitions are defined

the policy can support a future
live multisig migration package

--------------------------------------------------

12. CANONICAL STATUS

Target governance baseline:

5 signers
3 threshold

Current next institutional block:
guardian separation planning
