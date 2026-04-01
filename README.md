# NEXUS Finance — Smart Contracts

> Overcollateralized stablecoin infrastructure on Arbitrum.
> This document is the primary reviewer navigation map for **LOTIQUE LAB** and any third-party security auditor.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Architecture Map](#2-architecture-map)
3. [Key Security Design Decisions](#3-key-security-design-decisions)
4. [Protocol Invariants](#4-protocol-invariants)
5. [Reviewer Guide — Where to Look First](#5-reviewer-guide)
6. [Known Tradeoffs](#6-known-tradeoffs)
7. [Test Coverage Summary](#7-test-coverage-summary)
8. [Deployed Contracts](#8-deployed-contracts-arbitrum-sepolia)
9. [Development Quick Start](#9-development-quick-start)

---

## 1. System Overview

NEXUS is an overcollateralized stablecoin protocol. Users deposit WETH as collateral and mint **NXUSD**, a USD-pegged synthetic debt token. The protocol is non-algorithmic: every NXUSD in circulation is backed by on-chain collateral at a minimum ratio of 150%.

**Core properties:**

- NXUSD is minted only when the user's vault meets the minimum collateralization ratio (minCR ≥ 150%).
- NXUSD is a pure ERC-20 with role-gated mint/burn. No rebase, no algorithmic supply adjustment.
- Liquidation is enforced externally by the `LiquidationEngine` which respects a configurable close factor.
- Oracle price data is sourced from Chainlink with staleness, completeness, and L2 sequencer checks.
- Emergency bad debt is resolved via a guardian-only path (`resolveBadDebt`), not silent accounting.

---

## 2. Architecture Map

```
┌─────────────────────────────────────────────────────────────────────┐
│                          EXTERNAL ACTORS                            │
│  User (depositor/borrower)  │  Keeper (liquidation bot)  │  Admin   │
└──────────────┬──────────────┴────────────┬────────────────┴────┬────┘
               │                           │                     │
               ▼                           ▼                     │
      ┌─────────────────┐        ┌──────────────────┐           │
      │  VaultManager   │◄───────│ LiquidationEngine │           │
      │  (accounting)   │        │  (enforcement)    │           │
      └────────┬────────┘        └──────────────────┘           │
               │                         │                       │
         mint/burn                 vault.liquidate()             │
               ▼                         │                       │
      ┌─────────────────┐                │                       │
      │   NXUSDToken    │◄───────────────┘                       │
      │  (debt token)   │                                        │
      └─────────────────┘                                        │
               │                                                 │
         price checks                                            │
               ▼                                                 │
      ┌─────────────────┐                                        │
      │  OracleModule   │◄───────────────────────────────────────┘
      │  (price source) │        (setFeed, setMaxDelay, setSequencerFeed)
      └─────────────────┘
               ▲
        Chainlink AggregatorV3 (ETH/USD + sequencer uptime feed)
```

### Who calls what

| Caller | Target | Function | Notes |
|--------|--------|----------|-------|
| User | VaultManager | `deposit`, `withdraw`, `mint`, `burn` | Permissionless, pauseable |
| Keeper (via LiqEngine) | VaultManager | `liquidate` | **Only** `liqEngine` address may call this |
| Keeper | LiquidationEngine | `executeLiquidation` | Requires `KEEPER_ROLE` on LiqEngine |
| Guardian | VaultManager | `resolveBadDebt`, `pause` | Requires `GUARDIAN_ROLE` |
| Admin | VaultManager | `setOracle`, `setRatios`, `setMaxDelay`, `setLiquidationEngine` | Requires `DEFAULT_ADMIN_ROLE` |
| Admin | OracleModule | `setFeed`, `setMaxDelay`, `setSequencerFeed` | Requires `DEFAULT_ADMIN_ROLE` |
| Admin | LiquidationEngine | `setVault`, `setCloseFactor` | Requires `DEFAULT_ADMIN_ROLE` |
| Admin | NXUSDToken | `setMinter`, `setBurner`, `setMaxSupply` | Requires `DEFAULT_ADMIN_ROLE` |

### Where critical checks live

| Check | Location | Function |
|-------|----------|----------|
| Minimum CR enforcement | `VaultManager._isSafe()` | Called by `mint()` and `withdraw()` |
| Liquidation eligibility | `VaultManager.isLiquidatable()` | CR < liquidationRatioBps |
| Close factor limit | `LiquidationEngine.executeLiquidation()` | `repayAmount ≤ debt * closeFactorBps / 10000` |
| Oracle staleness (coarse) | `OracleModule.getPrice()` | `block.timestamp - updatedAt ≤ maxDelay` |
| Oracle staleness (fine) | `VaultManager._oracleSnapshot()` | Independent second window |
| Oracle round completeness | `OracleModule.getPrice()` | `answeredInRound >= roundId` |
| L2 sequencer uptime | `OracleModule.getPrice()` | Chainlink sequencer feed + grace period |
| Bad debt gateway | `VaultManager.resolveBadDebt()` | `seizeForFullDebt > collateral` required |

### What is intentionally separated

- **LiquidationEngine is not the accounting layer.** It only enforces the close factor and dispatches to the vault. It holds no collateral, no debt records.
- **NXUSDToken is not the policy layer.** It enforces minter/burner roles and an optional supply cap. All collateral logic is in VaultManager.
- **OracleModule is not the freshness arbiter alone.** VaultManager applies a second independent staleness window. This is defense-in-depth.

---

## 3. Key Security Design Decisions

### 3.1 Liquidation restricted to LiquidationEngine

`VaultManager.liquidate()` is gated by `require(msg.sender == liqEngine)`. No role (not even `KEEPER_ROLE` directly on the vault) can bypass this.

**Why:** Before this restriction, any address with `KEEPER_ROLE` on the vault could call `liquidate()` directly, bypassing `LiquidationEngine`'s close factor limit. A rogue keeper could liquidate 100% of any position in a single transaction regardless of the configured close factor. The restriction routes all liquidations through the engine, which enforces `repayAmount ≤ debt * closeFactorBps / 10000`.

**Configuration:** `liqEngine` defaults to `address(0)` (liquidation blocked). Admin must call `setLiquidationEngine(address(liqEngine))` post-deployment.

### 3.2 Bad debt is not burned immediately

When `resolveBadDebt()` is called, the debtor's vault state is zeroed and collateral is transferred to the guardian. The corresponding NXUSD **is not burned**. It remains in circulation, tracked by `totalBadDebt`.

**Why:** The vault does not hold NXUSD (it holds WETH). Burning NXUSD from circulation requires a separate protocol action (governance vote, recapitalization, or protocol treasury burn). Forcing a burn here would require the vault to hold NXUSD reserves, which is a significant design change. The current model makes the undercollateralization explicit and auditable on-chain via `totalBadDebt`.

**Auditor note:** `totalBadDebt` represents the NXUSD supply that is no longer backed by protocol collateral. Governance must track and address this. This is not a silent write-off.

### 3.3 Oracle checks: layered defense

The oracle safety model has five independent checks:

1. **Sequencer uptime** (`OracleModule`): On Arbitrum, validates the sequencer feed is active. Prevents accepting prices during sequencer downtime when positions could not be defended.
2. **Grace period** (`OracleModule`): After sequencer restart, enforces a 3600s buffer (`SEQ_GRACE_PERIOD`) before accepting any price. Prevents liquidation raids on positions that could not be defended during downtime.
3. **Staleness — oracle layer** (`OracleModule`): `block.timestamp - updatedAt ≤ maxDelay`.
4. **Staleness — vault layer** (`VaultManager._oracleSnapshot`): Independent second staleness window. Effective limit = min(oracle.maxDelay, vault.maxDelay).
5. **Round completeness** (`OracleModule`): `answeredInRound >= roundId`. Prevents consuming an incomplete Chainlink round where the aggregator has not yet written the answer for the current period.

### 3.4 Role separation: admin / guardian / keeper

| Role | Holder | Capabilities | Who holds it |
|------|--------|-------------|--------------|
| `DEFAULT_ADMIN_ROLE` | VaultManager, LiqEngine, OracleModule | Parameter changes, oracle rotation, liqEngine registration, role management | Safe 4-of-7 multisig |
| `GUARDIAN_ROLE` | VaultManager | `pause()`, `resolveBadDebt()` | Safe 4-of-7 multisig (same as admin at current stage) |
| `KEEPER_ROLE` | LiquidationEngine | `executeLiquidation()` | Keeper bot EOA/contract |
| `MINTER_ROLE` | NXUSDToken | `mint()` | VaultManager only |
| `BURNER_ROLE` | NXUSDToken | `burn()` | VaultManager only |

The vault's `KEEPER_ROLE` is granted to `LiquidationEngine` for operational compatibility (allows legacy role checks), but `liquidate()` now strictly requires `msg.sender == liqEngine`. The role alone is no longer sufficient to call `liquidate()`.

---

## 4. Protocol Invariants

These are the hard invariants the codebase is designed to enforce:

### INV-1: Collateral coverage at mint time
```
collateralOf[user] * price / denom * 10000 ≥ debtOf[user] * minCollateralRatioBps
```
Enforced by `_isSafe()` inside `mint()` and `withdraw()`. Cannot be bypassed.

### INV-2: No mint without collateral
`debtOf[user] > 0 ∧ collateralOf[user] == 0 → _isSafe() returns false → mint() reverts`.

### INV-3: Liquidation threshold is strictly below mint threshold
Constructor enforces `minCrBps ≥ liqCrBps`. The gap creates the liquidatable range.

### INV-4: Close factor is enforced for all liquidations
`repayAmount ≤ debtOf[account] * closeFactorBps / 10000` enforced in `LiquidationEngine.executeLiquidation()`. All vault liquidations must pass through the engine (`msg.sender == liqEngine`).

### INV-5: Bad debt is explicit
Irrecoverable positions are resolved only through `resolveBadDebt()`, which requires guardian authorization and verifies that normal liquidation is impossible (`seizeForFull > col`). The uncovered amount is recorded in `totalBadDebt`.

### INV-6: NXUSD supply is bounded (soft)
`NXUSDToken.maxSupply` provides an optional hard cap. If `maxSupply == 0`, the cap is disabled. Protocol governance must set this. Default at deployment is uncapped.

### INV-7: Oracle must be fresh and valid
All price-consuming paths (mint, withdraw, liquidate, resolveBadDebt, isLiquidatable) route through `_oracleSnapshot()` → `OracleModule.getPrice()`. If the oracle is stale, down, or incomplete, all price-dependent operations revert.

---

## 5. Reviewer Guide

### Where to look first

**Core vault logic — collateral, debt, CR enforcement:**
→ `src/vault/VaultManager.sol`
→ Focus: `_isSafe()`, `_oracleSnapshot()`, `liquidate()`, `resolveBadDebt()`

**Liquidation enforcement — close factor, keeper flow:**
→ `src/vault/LiquidationEngine.sol`
→ Focus: `executeLiquidation()` — token flow sequence, close factor check, vault call

**Oracle safety — staleness, sequencer, completeness:**
→ `src/oracle/OracleModule.sol`
→ Focus: `getPrice()` — all five check layers

**Debt token — mint/burn authorization, supply cap:**
→ `src/core/NXUSDToken.sol`
→ Focus: `mint()`, `burn()`, `setMaxSupply()`, role gating

---

### Token flow through a liquidation (step by step)

```
1. Keeper calls:   LiqEngine.executeLiquidation(account, repayAmount)
2. LiqEngine:      checks vault.isLiquidatable(account)
3. LiqEngine:      checks repayAmount ≤ debt * closeFactorBps / 10000
4. LiqEngine:      NXUSD.transferFrom(keeper → liqEngine, repayAmount)
5. LiqEngine:      NXUSD.transfer(liqEngine → account, repayAmount)
6. LiqEngine:      vault.liquidate(account, keeper, repayAmount)
7. VaultManager:   verifies msg.sender == liqEngine
8. VaultManager:   verifies account is liquidatable (re-checks CR)
9. VaultManager:   decrements debtOf[account], decrements collateralOf[account]
10. VaultManager:  NXUSD.burn(account, repayAmount)   ← burns the NXUSD we just sent
11. VaultManager:  COLLATERAL.transfer(keeper, seizeAmount)  ← keeper receives collateral
```

Steps 4–11 are a single atomic transaction. If any step reverts, all token moves unwind.

---

### High-attention areas

| Area | Why it needs close review |
|------|--------------------------|
| `resolveBadDebt()` oracle dependency | Calls `_oracleSnapshot()` — if oracle is stale during incident, guardian cannot clear bad debt even while vault is paused |
| Double staleness window | OracleModule + VaultManager each apply their own `maxDelay`. Effective limit = min(two). Ensure these are configured consistently in production. |
| `liqEngine` rotation | Admin can change `liqEngine` to a new engine with different close factor. Previous engine is immediately blocked. |
| `setOracle()` smoke-check | Calls `getPrice()` on the candidate oracle at commit time. Will revert if oracle is stale at that moment. Operational friction risk. |
| `maxSupply = 0` | No supply cap by default. Governance must set `setMaxSupply()` to activate the constitution's 1B NXUSD limit. |

---

## 6. Known Tradeoffs

These are intentional design choices, not bugs. Listed here so the auditor can focus on logic verification rather than questioning design intent.

### 6.1 Bad debt NXUSD is not burned immediately
The vault has no NXUSD reserves to absorb the undercollateralized supply. `totalBadDebt` makes the liability explicit. A governance recapitalization mechanism (out of scope for this audit) is the intended resolution path. The tradeoff: NXUSD peg integrity depends on governance acting promptly after bad debt events.

### 6.2 Reliance on external keepers for liquidation timing
The protocol has no on-chain automated liquidation. Positions that cross the liquidation threshold (130% CR) are only liquidated when a keeper calls `executeLiquidation()`. During keeper inactivity or gas spikes, positions can become more deeply undercollateralized. The `resolveBadDebt()` guardian path exists specifically to handle the cases where the keeper bonus makes normal liquidation impossible.

### 6.3 Oracle dependency is unavoidable
All price-sensitive operations revert when the oracle is stale or the sequencer is down. This is the correct behavior on L2. The tradeoff: during Chainlink downtime, users cannot mint, withdraw (if they have debt), or be liquidated. The 7-day `MAX_DELAY` hard cap and the 1-hour production `maxDelay` provide the operational envelope.

### 6.4 Close factor operates on the LiqEngine, not the vault
The close factor limit lives in `LiquidationEngine`. If admin rotates to a new engine with a higher close factor, previous protections no longer apply to new liquidations. This is a governance responsibility: any new `liqEngine` must be reviewed before activation.

### 6.5 Guardian receives collateral from bad debt resolution
When `resolveBadDebt()` is called, the remaining collateral is transferred to the guardian's address (the caller). With a Safe multisig as guardian, this requires 4-of-7 approval. The mechanism is a practical emergency path, not a fee mechanism.

---

## 7. Test Coverage Summary

**Total: 197 tests across 14 suites. 197/197 passing.**

| Suite | Tests | Focus |
|-------|-------|-------|
| `VaultManager.t.sol` | 5 | Core happy-path: deposit/withdraw/mint/burn/liquidate |
| `VaultManagerAdversarial.t.sol` | 58 | Constructor guards, CR boundary precision, oracle staleness propagation, pause behavior, liquidation input validation, CEI ordering |
| `VaultBadDebt.t.sol` | 12 | H-04: bad debt resolution, accounting correctness, event emission, pause bypass, unauthorized access |
| `VaultLiqEngineRestriction.t.sol` | 11 | Task 1: liqEngine gate, keeper bypass prevention, admin-only setter, event, rotation |
| `LiquidationEngine.t.sol` | 5 | Happy-path liquidation, close factor, keeper-only gate |
| `LiquidationEngineAdversarial.t.sol` | 21 | Constructor guards, close factor boundary, full liquidation at 100%, NXUSD flow correctness |
| `LiquidationPause.t.sol` | 4 | Pause blocks execution, guardian pause/unpause paths |
| `OracleModule.t.sol` | 5 | Happy-path price fetch, decimals, maxDelay, setFeed |
| `OracleModuleAdversarial.t.sol` | 19 | Constructor guards, setFeed smoke-check, staleness, future timestamp, stale round (Task 2) |
| `OracleModuleSequencer.t.sol` | 10 | H-03: sequencer down, grace period, restart timing, disabled check |
| `NXUSDToken.t.sol` | 8 | Mint/burn happy-path, role gating, supply cap |
| `NXUSDTokenAdversarial.t.sol` | 13 | Constructor, role guards, cap below supply, zero-address minting |
| `TimelockGovernance.t.sol` | 21 | Governance timelock mechanics |
| `VaultPause.t.sol` | 5 | Pause blocks all user operations |

**Test types:**
- **Adversarial / negative path:** ~140 tests (reverts, access control, boundary values)
- **Happy path / integration:** ~40 tests
- **Invariant-like / state verification:** ~17 tests (CEI ordering, accounting correctness, event emission)

---

## 8. Deployed Contracts (Arbitrum Sepolia)

| Contract | Address | Status |
|----------|---------|--------|
| NXUSDToken | `0x515844Dd91956C749e33521B4f171dac4e04FE07` | Live |
| VaultManager | `0xF09AAD220C6c4d805cF6cE5561B546f51ADFBb03` | Live |
| LiquidationEngine | `0xF333d9ae2D70305758E714ecBeA938e9377a9f9D` | Live |
| OracleModule | `0xa1BD5AF1174140caB018e46eBCFEf1d005c3df84` | Live |
| WETH (collateral) | `0x980B62Da83eFf3D4576C647993b0c1D7faf17c73` | Live |
| Safe Multisig | `0x8626240187bb366a8566D338b84a7F84f237164F` | Live (4-of-7) |

**Production parameters:**
- Min collateral ratio: 150% (15000 bps)
- Liquidation threshold: 130% (13000 bps)
- Keeper bonus: 5% (hardcoded in `_seizeAmountForRepay`)
- Close factor: 50% (5000 bps, configurable)
- Oracle maxDelay: 1 hour (both OracleModule and VaultManager)
- Oracle: Chainlink ETH/USD (8 decimals)
- L2 sequencer feed: Arbitrum sequencer uptime feed

---

## 9. Development Quick Start

```bash
# Build
forge build

# Run full test suite
forge test

# Run with gas reporting
forge test --gas-report

# Run specific suite
forge test --match-contract VaultManagerAdversarialTest

# Deploy (requires .env with PRIVATE_KEY, ADMIN, ORACLE_FEED, etc.)
forge script script/DeployCore.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast
```

**Repository structure:**
```
nexus-contracts/
├── src/
│   ├── core/       NXUSDToken.sol
│   ├── vault/      VaultManager.sol, LiquidationEngine.sol
│   └── oracle/     OracleModule.sol
├── test/           Forge test suites (14 files, 197 tests)
├── script/         Deployment scripts
├── deployments/    Address registries (JSON)
├── docs/           Internal documentation
└── constitution/   Protocol invariant definitions
```

---

## License

Proprietary — NEXUS Finance © 2026
