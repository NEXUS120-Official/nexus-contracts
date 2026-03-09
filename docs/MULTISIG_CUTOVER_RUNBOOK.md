# MULTISIG CUTOVER RUNBOOK

## Objective

Transfer canonical admin authority from legacy EOA admin to Safe multisig without altering guardian or keeper separation.

## Sequence

### Phase 1 - Admin grant

Run script/MultisigAdminGrant.s.sol to grant DEFAULT_ADMIN_ROLE to the Safe on:

- NXUSDToken
- OracleModule
- VaultManager
- LiquidationEngine

### Phase 2 - Dual-topology verification

Run script/MultisigGovernanceVerify.s.sol with:

- EXPECT_OLD_ADMIN_PRESENT=true
- EXPECT_SAFE_CODE=true

Pass condition:

- Safe admin present on all contracts
- old admin still present on all contracts
- guardian unchanged
- keeper unchanged
- capability checks pass

### Phase 3 - Legacy revoke

Run script/MultisigAdminRevoke.s.sol to revoke DEFAULT_ADMIN_ROLE from OLD_ADMIN on all 4 contracts.

### Phase 4 - Final verification

Run script/MultisigGovernanceVerify.s.sol with:

- EXPECT_OLD_ADMIN_PRESENT=false
- EXPECT_SAFE_CODE=true

Pass condition:

- Safe admin present on all contracts
- old admin removed on all contracts
- guardian unchanged
- keeper unchanged
- capability checks pass

## Finalization

Update:

- deployments/arbitrum-sepolia-multisig.json
- deployments/arbitrum-sepolia-governance-final.json
- docs/CHECKPOINT_MULTISIG_GOVERNANCE_ACTIVATION_2026-03-09.md
