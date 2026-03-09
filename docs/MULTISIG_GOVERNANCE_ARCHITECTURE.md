# MULTISIG GOVERNANCE ARCHITECTURE

## Objective

Elevate NEXUS contracts governance from separated EOA admin topology to institutional Safe-based admin control.

## Canonical target topology

- ADMIN: Safe multisig (4/7)
- GUARDIAN: separate address
- KEEPER: separate address

## Current canonical separated operators

- GUARDIAN: 0x8EC04BBC3E3f8256d1295a6Be25ebF8DacC40c5a
- KEEPER: 0x8150dbba9F0960300a360033882685ca450a7038

## Governance doctrine

The Safe becomes the sole canonical admin authority for:

- NXUSDToken
- OracleModule
- VaultManager
- LiquidationEngine

The Safe does not replace the guardian role.

The Safe does not replace the keeper role.

## Activation model

1. Deploy Safe 4/7
2. Grant DEFAULT_ADMIN_ROLE to Safe
3. Verify dual topology
4. Revoke legacy EOA admin
5. Verify final topology
6. Update canonical registry and checkpoint

## Security posture

- no single human admin
- dual-topology verify required before destructive revoke
- guardian remains independent for emergency pause
- keeper remains independent for operations
- final state must be replayable and registry-backed
