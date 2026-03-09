# MULTISIG DEPLOY RUNBOOK

## Scope

Deploy a Safe multisig on Arbitrum Sepolia with:

- 7 signers
- threshold 4

## Required outputs

- Safe address
- signer list
- threshold confirmation
- deployment tx hash
- setup tx hash
- deployment block number

## Constraints

- Safe must be deployed before any admin grant
- Safe address must be contract code-bearing
- signer set must be recorded in deployments/arbitrum-sepolia-multisig.json

## Pre-flight checklist

- signer set fixed
- threshold fixed at 4/7
- guardian remains separate
- keeper remains separate
- old admin remains active until dual-topology verify passes

## Post-deploy checklist

- safe address recorded
- code length confirmed > 0
- threshold confirmed = 4
- signer count confirmed = 7
- registry updated from PREPARED_NOT_DEPLOYED to DEPLOYED_NOT_GRANTED
