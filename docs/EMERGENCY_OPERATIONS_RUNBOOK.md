# EMERGENCY OPERATIONS RUNBOOK — NEXUS CONTRACTS

Status: CANONICAL DRAFT
Standard: TOP-5 ELITE / audit-grade
Repo: nexus-contracts
Branch: law-phase1
Network: Arbitrum Sepolia

--------------------------------------------------

1. PURPOSE

This document defines the canonical
emergency operations runbook
for the NEXUS CONTRACTS layer.

It exists to formalize
incident response actions
for pause-sensitive contracts.

This document is operations-critical.

Primary objective:

preserve protocol controllability
during abnormal conditions.

--------------------------------------------------

2. CONTRACTS IN SCOPE

VaultManager

LiquidationEngine

These contracts currently include
emergency pause controls.

Pause-sensitive functions include:

VaultManager
deposit
withdraw
mint
burn
liquidate

LiquidationEngine
executeLiquidation

This runbook applies only
to emergency operational handling.

It does not redefine protocol economics.

--------------------------------------------------

3. AUTHORITY MODEL

GUARDIAN_ROLE

may trigger pause
on pause-enabled contracts.

DEFAULT_ADMIN_ROLE

may perform unpause
where implemented by contract design.

Canonical principle:

pause authority and recovery authority
must remain explicitly identified.

Unpause is never assumed.

--------------------------------------------------

4. INCIDENT CLASSES

Class 1
Operational anomaly

Examples:

unexpected revert pattern
unexpected role mismatch

keeper malfunction
non-critical deployment mismatch

Class 2
Security-sensitive anomaly

Examples:

unexpected state transition
unexpected liquidation behavior

oracle configuration anomaly
unauthorized operational behavior

Class 3
Critical protocol threat

Examples:

privilege compromise
active exploit suspicion

loss of admin control
loss of guardian control
live solvency-threatening condition

Class 3 events are pause-immediate
unless proven false.

--------------------------------------------------
5. PAUSE DECISION RULE

Pause is justified when
continuing live operations
creates higher risk than
temporary operational freeze.

Pause is strongly indicated when:

state correctness is uncertain

privileged control is uncertain

oracle integrity is uncertain

liquidation correctness is uncertain

unauthorized behavior is suspected

exploit conditions are plausible

--------------------------------------------------

6. PAUSE EXECUTION PROCEDURE

Step 1
identify affected contract

Step 2
classify incident severity

Step 3
confirm guardian authority available

Step 4
execute pause transaction

Step 5
confirm on-chain pause state

Step 6
record incident evidence

Step 7
freeze non-essential changes

During emergency handling:

do not mix remediation
with unrelated changes

do not rotate roles mid-incident
unless role compromise is involved

do not unpause without verification

--------------------------------------------------

7. EVIDENCE TO RECORD

At minimum record:

timestamp
network
contract affected
incident class
trigger reason

pause tx hash
operator identity
observed symptoms
temporary containment status
next required action

Evidence must be sufficient
for ex-post audit reconstruction.

--------------------------------------------------

8. UNPAUSE CONDITIONS

Unpause is allowed only when:

root cause is identified

containment succeeded

state correctness is revalidated

required authority is confirmed

no active exploit path remains

post-incident checks are complete

Unpause is a governed recovery action,
not a convenience action.

--------------------------------------------------

9. EXPLICIT UNPAUSE PROHIBITIONS

Do not unpause because:

time has passed

pressure exists to resume quickly

monitoring is incomplete

root cause is still ambiguous

verification is still pending

authority ownership is unclear

If in doubt,
remain paused.

--------------------------------------------------

10. ESCALATION MODEL

Operational anomaly
escalate to protocol operator

Security-sensitive anomaly
escalate to governance and guardian

Critical threat

escalate immediately to
guardian authority
governance authority
security lead
core protocol operator

Escalation must be immediate
for Class 3 incidents.

--------------------------------------------------

11. EXPLICIT NON-GOALS

This runbook does not by itself:

change governance topology

change admin migration order

change oracle policy

change economic parameters

change liquidation fee policy

authorize discretionary protocol redesign

This runbook governs emergency action only.

--------------------------------------------------

12. ACCEPTANCE CRITERIA

This runbook is acceptable when:

incident classes are defined

pause authority is defined

unpause conditions are defined

evidence requirements are defined

escalation paths are defined

emergency handling is reproducible

audit reconstruction is possible

--------------------------------------------------

13. CANONICAL STATUS STATEMENT

This document defines the
minimum institutional standard
for emergency pause operations
in the current NEXUS CONTRACTS layer.

Core rule:

when uncertainty is material,
contain first, resume later.
