# NEXUS Finance — Audit Readiness Skeleton
## Version 1.0 · Arbitrum Sepolia Testnet

**Status:** Phase 1 skeleton — first substantive version. Not audit-complete.
**Network:** Arbitrum Sepolia (chain ID 421614)
**Prepared:** 2026-03-21
**Scope:** On-chain contracts, governance posture, off-chain infrastructure surface

> This document is intended as an orientation package for a security firm, technical
> reviewer, or protocol partner approaching a formal audit engagement. It is honest about
> what has and has not been done. Sections marked **[OPEN]** identify gaps that require
> further work before a full audit is appropriate.

---

## 1. SYSTEM OVERVIEW

### Protocol Summary

NEXUS Finance is an overcollateralised credit protocol. Users deposit WETH as collateral
and mint NXUSD — a protocol-issued stablecoin — against it. The protocol enforces solvency
through on-chain collateral ratio constraints enforced at every state-changing operation.
A keeper-operated liquidation engine resolves undercollateralised positions.

### Key System Components

| Component | Role |
|---|---|
| `NXUSDToken` | Protocol stablecoin. Minimal ERC-20 with role-gated mint and burn. No monetary policy logic — that lives in VaultManager. |
| `OracleModule` | Wraps a Chainlink AggregatorV3 feed. Validates freshness (`maxDelay`), sign, and timestamp before returning a price. Reverts if any condition fails. |
| `VaultManager` | Core state contract. Holds per-user collateral and debt mappings. Enforces collateral ratio at mint, withdraw, and liquidate. Issues mint/burn calls to NXUSDToken. |
| `LiquidationEngine` | Keeper-facing liquidation interface. Validates liquidatability via VaultManager, enforces a close factor cap, and orchestrates the repay-and-seize flow. |
| Safe multisig | Governance control surface. Holds `DEFAULT_ADMIN_ROLE` across all core contracts. 4-of-7 threshold, Arbitrum Sepolia. |
| NEXUS-120 Engine | Off-chain audit engine (Python). Runs SOV_001, SOV_003, SOV_005 pillar checks per tick. Generates SHA-256-hashed hourly receipt packages. Not a system contract. |

### Component Relationships

```
Safe (4-of-7 multisig)
  └─► DEFAULT_ADMIN_ROLE on: NXUSDToken, OracleModule, VaultManager, LiquidationEngine

OracleModule
  └─► Chainlink AggregatorV3 feed (ETH/USD on Arbitrum Sepolia)
  └─► Called by VaultManager._oracleSnapshot() on every state-changing op

VaultManager
  └─► holds collateralOf[address] and debtOf[address]
  └─► calls NXUSDToken.mint() and .burn() on mint/burn ops
  └─► exposes liquidate() to KEEPER_ROLE (held by LiquidationEngine)

LiquidationEngine
  └─► calls VaultManager.isLiquidatable() before each liquidation
  └─► pulls NXUSD from keeper via transferFrom
  └─► calls VaultManager.liquidate() to execute seize
  └─► constrained by closeFactorBps (max 50% of debt per call)

NEXUS-120 Engine (off-chain)
  └─► reads chain state via public RPC
  └─► publishes receipts to nexus-receipts repo
  └─► NOT a trust boundary for on-chain execution
```

---

## 2. CONTRACT INVENTORY

**Deployment method:** `DeployCoreHardened.s.sol` via Forge broadcast.
**Deployer:** `0xB4518cebFf8a92A8514f90F21B86e7Cb987F4ab6`
**Deploy block:** 248,448,302 (Arbitrum Sepolia)
**Deploy tx (NXUSDToken):** `0xb6f6f9d05b8e8c301e98e5b3fa46c9d808c73337a95c11cbc15efc591c993a5a`

### Core Protocol Contracts

| Contract | Address | Chain | Role |
|---|---|---|---|
| NXUSDToken | `0x515844Dd91956C749e33521B4f171dac4e04FE07` | Arbitrum Sepolia | Protocol stablecoin (ERC-20 + AccessControl) |
| OracleModule | `0xa1BD5AF1174140caB018e46eBCFEf1d005c3df84` | Arbitrum Sepolia | Price abstraction layer over Chainlink |
| VaultManager | `0xF09AAD220C6c4d805cF6cE5561B546f51ADFBb03` | Arbitrum Sepolia | Collateral + debt state; mint/burn gating |
| LiquidationEngine | `0xF333d9ae2D70305758E714ecBeA938e9377a9f9D` | Arbitrum Sepolia | Keeper-operated liquidation interface |

### Governance and External Contracts

| Contract | Address | Chain | Role |
|---|---|---|---|
| Safe multisig | `0x8626240187bb366a8566D338b84a7F84f237164F` | Arbitrum Sepolia | Protocol governance — holds DEFAULT_ADMIN_ROLE on all core contracts |
| WETH (collateral) | `0x980B62Da83eFf3D4576C647993b0c1D7faf17c73` | Arbitrum Sepolia | Standard WETH ERC-20; sole accepted collateral |
| Chainlink ETH/USD | `0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165` | Arbitrum Sepolia | Active price feed inside OracleModule |

### Upgradeability

None of the core contracts (NXUSDToken, OracleModule, VaultManager, LiquidationEngine)
are upgradeable proxies. They are deployed as standard non-proxy contracts. The oracle
feed address and vault oracle reference can be changed by the admin role, but the
contract bytecode is immutable.

**Immutable constructor parameters:**
- `VaultManager.COLLATERAL` — immutable; set to WETH at deploy
- `VaultManager.NXUSD` — immutable; set to NXUSDToken at deploy
- `LiquidationEngine.NXUSD` — immutable; set to NXUSDToken at deploy

**Mutable storage (admin-controlled):**
- `OracleModule.feed` — changeable via `setFeed()`
- `OracleModule.maxDelay` — changeable via `setMaxDelay()`
- `VaultManager.oracle` — changeable via `setOracle()`
- `VaultManager.minCollateralRatioBps` / `liquidationRatioBps` — changeable via `setRatios()`
- `VaultManager.maxDelay` — changeable via `setMaxDelay()`
- `LiquidationEngine.vault` — changeable via `setVault()`
- `LiquidationEngine.closeFactorBps` — changeable via `setCloseFactor()`

---

## 3. PRIVILEGED FUNCTIONS MAP

### Role Definitions

| Role | Hash | Scope |
|---|---|---|
| `DEFAULT_ADMIN_ROLE` | `0x00...00` | Root authority. Manages other roles. Currently held by Safe multisig. |
| `MINTER_ROLE` (NXUSDToken) | `keccak256("MINTER_ROLE")` | Permits calls to `NXUSDToken.mint()`. Held by VaultManager. |
| `BURNER_ROLE` (NXUSDToken) | `keccak256("BURNER_ROLE")` | Permits calls to `NXUSDToken.burn()`. Held by VaultManager. |
| `GUARDIAN_ROLE` (Vault + LiqEngine) | `keccak256("GUARDIAN_ROLE")` | Emergency pause authority. Separate from admin. |
| `KEEPER_ROLE` (Vault + LiqEngine) | `keccak256("KEEPER_ROLE")` | Liquidation execution authority. |

### Current Role Holders (Live State)

| Role | Contract | Current Holder | How Assigned |
|---|---|---|---|
| `DEFAULT_ADMIN_ROLE` | NXUSDToken | Safe `0x8626...164F` | Transferred from deployer EOA via governance migration |
| `DEFAULT_ADMIN_ROLE` | OracleModule | Safe `0x8626...164F` | As above |
| `DEFAULT_ADMIN_ROLE` | VaultManager | Safe `0x8626...164F` | As above |
| `DEFAULT_ADMIN_ROLE` | LiquidationEngine | Safe `0x8626...164F` | As above |
| `MINTER_ROLE` | NXUSDToken | VaultManager `0xF09A...Bb03` | Set during `DeployCoreHardened` |
| `BURNER_ROLE` | NXUSDToken | VaultManager `0xF09A...Bb03` | Set during `DeployCoreHardened` |
| `GUARDIAN_ROLE` | VaultManager | **[OPEN — verify current holder]** | Assigned at deploy; confirm not revoked |
| `GUARDIAN_ROLE` | LiquidationEngine | **[OPEN — verify current holder]** | Assigned at deploy; confirm not revoked |
| `KEEPER_ROLE` | LiquidationEngine | `0x8150dbba9f0960300a360033882685ca450a7038` | Granted via Safe `execTransaction` (SafeExecGrantVaultKeeper broadcast) |
| `KEEPER_ROLE` | VaultManager | LiquidationEngine `0xF333...9f9D` | Set during `DeployCoreHardened` (vault.liquidate() access) |

### Privileged Function Catalogue

#### NXUSDToken

| Function | Required Role | Effect | Risk Weight |
|---|---|---|---|
| `setMinter(address, bool)` | DEFAULT_ADMIN_ROLE | Grants or revokes MINTER_ROLE | HIGH — a rogue minter can create unbacked NXUSD |
| `setBurner(address, bool)` | DEFAULT_ADMIN_ROLE | Grants or revokes BURNER_ROLE | HIGH — a rogue burner can destroy user balances |
| `grantRole` / `revokeRole` | DEFAULT_ADMIN_ROLE | Standard OZ AccessControl | HIGH |

#### OracleModule

| Function | Required Role | Effect | Risk Weight |
|---|---|---|---|
| `setFeed(address)` | DEFAULT_ADMIN_ROLE | Changes active Chainlink feed | CRITICAL — a malicious feed can manipulate all CR checks |
| `setMaxDelay(uint256)` | DEFAULT_ADMIN_ROLE | Changes staleness tolerance | HIGH — setting too large disables freshness protection |

#### VaultManager

| Function | Required Role | Effect | Risk Weight |
|---|---|---|---|
| `setOracle(address)` | DEFAULT_ADMIN_ROLE | Replaces the oracle contract | CRITICAL — arbitrary oracle can forge any price |
| `setRatios(uint256, uint256)` | DEFAULT_ADMIN_ROLE | Changes minCR and liqCR bps | HIGH — lowering these weakens solvency constraints |
| `setMaxDelay(uint256)` | DEFAULT_ADMIN_ROLE | Changes oracle freshness tolerance | HIGH |
| `pause()` | GUARDIAN_ROLE | Blocks all user-facing ops | MEDIUM — disables deposit, withdraw, mint, burn, liquidate |
| `unpause()` | DEFAULT_ADMIN_ROLE | Restores operations | MEDIUM |
| `liquidate(address, address, uint256)` | KEEPER_ROLE | Seizes collateral, burns debt | HIGH — called only via LiquidationEngine in normal ops |

#### LiquidationEngine

| Function | Required Role | Effect | Risk Weight |
|---|---|---|---|
| `setVault(address)` | DEFAULT_ADMIN_ROLE | Replaces target vault | CRITICAL — can point liquidations at arbitrary contract |
| `setCloseFactor(uint256)` | DEFAULT_ADMIN_ROLE | Changes max repay per liquidation (bps) | MEDIUM |
| `pause()` | GUARDIAN_ROLE | Halts liquidation engine | MEDIUM |
| `unpause()` | DEFAULT_ADMIN_ROLE | Restores liquidation engine | MEDIUM |
| `executeLiquidation(address, uint256)` | KEEPER_ROLE | Full liquidation execution path | HIGH |

### Safe Multisig Governance Surface

All `DEFAULT_ADMIN_ROLE` actions require a **4-of-7 Safe threshold** on Arbitrum Sepolia.

Safe address: `0x8626240187bb366a8566D338b84a7F84f237164F`
Confirmed executed Safe transactions:
- `OracleModule.setFeed(0xd30e...5165)` — switched feed from MockAggregatorV3 to live Chainlink (broadcast `SafeExecSetFeed`)
- `VaultManager.grantRole(KEEPER_ROLE, 0x8150...7038)` — granted keeper to external address (broadcast `SafeExecGrantVaultKeeper`)

> **Auditor note:** GUARDIAN_ROLE holder should be verified on-chain via
> `hasRole(GUARDIAN_ROLE, address)` before any engagement. The deploy script
> assigned GUARDIAN_ROLE to the guardian address from env; the current live
> holder is not confirmed in this document.

---

## 4. EXTERNAL DEPENDENCIES

### Chainlink Oracle (ETH/USD)

| Property | Value |
|---|---|
| Feed address | `0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165` |
| Network | Arbitrum Sepolia |
| Freshness window | 3600 seconds (1 hour) in OracleModule |
| Freshness window | 3600 seconds (1 hour) in VaultManager (`maxDelay`) |
| Interface assumed | `AggregatorV3Interface` — `latestRoundData()`, `decimals()` |
| Staleness behavior | `OracleModule.getPrice()` reverts if `block.timestamp - updatedAt > maxDelay` |
| Downstream effect | Oracle stale → all VaultManager ops revert (mint, withdraw, liquidate are all blocked) |

**Dependency risk:** If the Chainlink Arbitrum Sepolia feed goes stale (common on testnets),
the protocol enters a state where user operations revert on-chain. The off-chain API
(`/api/status`) falls back to reading Chainlink directly and classifies this as
`oracle_stale: true` with `price_source: chainlink_fallback`. The on-chain contracts
have no fallback and halt.

### Safe Multisig (Gnosis Safe v1.3.x)

The governance layer relies on the Safe contract at the address listed above.
Safe is an audited, widely deployed multisig framework. The protocol's security
is bounded by the Safe threshold integrity and the security of the signer keys.

**Current threshold:** 4-of-7
**Key rotation history:** Owner set was rotated after compromised keys were identified.
The rotation used a MultiSend DELEGATECALL batch to execute four `removeOwner` calls
atomically without dropping below threshold.

### WETH Token

Standard WETH contract on Arbitrum Sepolia. Used as the sole accepted collateral.
The VaultManager holds WETH via `transferFrom` on deposit and returns it via `transfer`
on withdrawal or liquidation. No custom WETH logic — standard ERC-20 assumptions apply.

**`COLLATERAL` is immutable in VaultManager.** A different collateral type would require
redeployment.

### NEXUS-120 Engine (Off-chain)

A Python-based audit engine that:
- Reads chain state via public RPC
- Evaluates SOV_001 (economic solvency), SOV_003 (capital adequacy — full version),
  SOV_005 (risk lattice — 5-year stress scenarios) per tick
- Generates SHA-256 hashed receipt packages (hourly)
- Publishes receipts to the `nexus-receipts` public GitHub repository

The engine is not a system contract. Its verdict does not affect on-chain execution.
It is an audit trail and monitoring layer. The canonical verdict source for external
integrations is `/api/receipts`, not `/api/status` (which uses a simplified runtime proxy).

### Arbitrum Sepolia Infrastructure

The protocol is deployed exclusively on Arbitrum Sepolia (chain ID 421614). There is
no mainnet deployment. Arbitrum Sepolia is an L2 testnet with standard Arbitrum Nitro
L2 semantics, but it is not a production environment. Gas costs are testnet-grade and
feed freshness is less reliable than on mainnet.

---

## 5. INVARIANTS / SECURITY-CRITICAL LOGIC

### I-01 — Mint Collateral Ratio Gate

**Rule:** A mint operation must not result in the caller's CR falling below
`minCollateralRatioBps / 10000` at the oracle price at the time of the transaction.

**Implementation:** `VaultManager.mint()` increments `debtOf[msg.sender]` first,
then calls `_isSafe()`, then calls `NXUSD.mint()`. If `_isSafe()` returns false,
the transaction reverts with "VAULT: unsafe mint".

**Dependency:** Oracle must be live. If oracle reverts, mint reverts.

**Current value:** `minCollateralRatioBps = 15000` (150%)

---

### I-02 — Withdrawal Safety Gate

**Rule:** A withdrawal must not result in the caller's CR falling below
`minCollateralRatioBps` after the withdrawal.

**Implementation:** `VaultManager.withdraw()` decrements `collateralOf[msg.sender]` first,
then calls `_isSafe()`. Reverts with "VAULT: unsafe after withdraw" on failure.

---

### I-03 — Liquidation Eligibility

**Rule:** A vault is only liquidatable if its current CR is strictly below
`liquidationRatioBps / 10000`.

**Implementation:** `VaultManager.liquidate()` recalculates CR from live oracle price
and checks `value18 * 10000 < d * liquidationRatioBps`. Reverts with "VAULT: not
liquidatable" if the condition is not met at execution time.

**Current value:** `liquidationRatioBps = 13000` (130%)

---

### I-04 — Keeper Bonus (5%)

**Rule:** The collateral seized during liquidation equals the NXUSD repaid amount
converted to ETH at current price, multiplied by 1.05 (5% bonus).

**Implementation:** `_seizeAmountForRepay()` applies `bonusAdjusted = repayAmount * 10500 / 10000`.
If `seizeAmount > collateralOf[account]`, the transaction reverts.

---

### I-05 — Close Factor Cap

**Rule:** A single liquidation call cannot repay more than `closeFactorBps / 10000`
of the target's outstanding debt.

**Implementation:** `LiquidationEngine.executeLiquidation()` computes
`maxRepay = debt * closeFactorBps / 10000` and reverts if `repayAmount > maxRepay`.

**Current value:** `closeFactorBps = 5000` (50%)

---

### I-06 — Oracle Freshness

**Rule:** The oracle price is only accepted if the Chainlink feed's `updatedAt`
timestamp satisfies both `block.timestamp >= updatedAt` (no future timestamps)
and `block.timestamp - updatedAt <= maxDelay`.

**Implementation:** Enforced in both `OracleModule.getPrice()` and
`VaultManager._oracleSnapshot()`. If either reverts, the calling operation reverts.

**Implication:** Oracle staleness propagates as a complete halt of vault operations.
There is no graceful degradation path on-chain.

---

### I-07 — Debt/Collateral Accounting

**Rule:** `collateralOf[user]` and `debtOf[user]` are incremented and decremented
atomically within each operation. No external ERC-20 transfer is initiated before
the invariant check passes.

**Mint path:** debt incremented → `_isSafe()` checked → `NXUSD.mint()` called.
**Withdraw path:** collateral decremented → `_isSafe()` checked → `COLLATERAL.transfer()` called.
**Liquidate path:** debt and collateral decremented → `NXUSD.burn()` called → `COLLATERAL.transfer()` called.

---

### I-08 — NXUSD Mint/Burn Authorization

**Rule:** Only addresses holding `MINTER_ROLE` or `BURNER_ROLE` can call
`NXUSDToken.mint()` or `NXUSDToken.burn()`. Role management requires `DEFAULT_ADMIN_ROLE`
(held by the Safe).

**Implication:** A compromise of the Safe or a malicious `setMinter` / `setBurner` call
is the only on-chain path to unauthorized NXUSD creation or destruction.

---

### I-09 — No Supply Cap Enforcement On-Chain

The `NexusEconomicConstitution` contract (`constitution/constitution_engine.sol`) defines
`MAX_NXUSD_SUPPLY = 1,000,000,000 ether` as a reference invariant. **This contract is not
deployed and is not integrated into the live system.** There is currently no on-chain
enforcement of a NXUSD supply ceiling. This is a known gap.

---

## 6. KNOWN LIMITATIONS / CURRENT CONSTRAINTS

### L-01 — Testnet Only

The current deployment is exclusively on Arbitrum Sepolia. There is no mainnet deployment.
All contract addresses, oracle feeds, and Safe signers correspond to the testnet.

### L-02 — Oracle Stale on Testnet

The Chainlink Arbitrum Sepolia ETH/USD feed (`0xd30e...5165`) regularly goes stale
relative to the 3600-second `maxDelay`. When stale, `OracleModule.getPrice()` reverts,
blocking all VaultManager state-changing operations (deposit is unaffected; it does not
call the oracle). The off-chain engine and API surface classify this as `oracle_stale: true`
and use a direct Chainlink fallback for display, but on-chain operations remain halted.

### L-03 — No Public Liquidation Execution

`LiquidationEngine.executeLiquidation()` requires `KEEPER_ROLE`. External testers and
general users cannot execute liquidations. The keeper address holding this role is
`0x8150dbba9f0960300a360033882685ca450a7038`.

### L-04 — GUARDIAN_ROLE Concentration

The GUARDIAN_ROLE on both VaultManager and LiquidationEngine should be held by an
authority separate from DEFAULT_ADMIN_ROLE. Current holder requires on-chain verification.
Before a mainnet deployment, guardian separation (documented in `docs/GUARDIAN_SEPARATION_PLAN.md`)
must be implemented.

### L-05 — No Supply Cap On-Chain

As noted in I-09, there is no on-chain NXUSD supply cap. The `NexusEconomicConstitution`
reference contract is not deployed or integrated. A binding supply cap is future work.

### L-06 — Single Collateral Type

The protocol currently accepts only WETH. The `COLLATERAL` address is immutable in
VaultManager. Multi-collateral support would require a new contract deployment.

### L-07 — Verdict Divergence Between Runtime UI and Engine

`/api/status` computes a simplified SOV_003 verdict (CR ≥ 130% AND oracle live).
The NEXUS-120 Engine computes a full capital adequacy check (concentration, runway,
surplus, peg risk). These can and do diverge. The engine verdict in `/api/receipts`
is the canonical audit-grade source. The runtime verdict carries `verdict_source: "simplified_runtime"`.

### L-08 — Off-Chain Engine Not Formally Verified

The NEXUS-120 Engine produces pillar verdicts and receipts. Its internal logic (SOV_003
capital adequacy, SOV_005 risk lattice) has not undergone formal verification or
independent audit. Receipt hashes provide integrity for the outputs, but not correctness
of the pillar logic.

### L-09 — No Formal Test Coverage Report

Test files exist (`test/VaultManager.t.sol`, `test/LiquidationEngine.t.sol`, `test/NXUSDToken.t.sol`,
`test/OracleModule.t.sol`, `test/VaultPause.t.sol`, `test/LiquidationPause.t.sol`) but no
formal coverage report has been produced and included in this package. **[OPEN]**

---

## 7. AUDIT HANDOFF NOTES

### Where to Start

An auditor should prioritise in the following order:

1. **`src/vault/VaultManager.sol`** — Core state logic. The CR invariants, oracle integration,
   and mint/burn authorization path are the highest-value attack surfaces. Focus on:
   - `_isSafe()` and `_oracleSnapshot()` interaction
   - Ordering of state mutations vs. external calls in `mint()`, `withdraw()`, `liquidate()`
   - `setOracle()` — what a malicious oracle can do
   - `setRatios()` — bounds checks are present but consequences of boundary values

2. **`src/vault/LiquidationEngine.sol`** — Liquidation execution path. Focus on:
   - NXUSD flow: transferFrom keeper → transfer to account → vault.liquidate() burns it
   - Whether the close factor can be bypassed
   - Interaction between LiquidationEngine and VaultManager on reverts

3. **`src/oracle/OracleModule.sol`** — Price oracle abstraction. Focus on:
   - `getPrice()` validity checks (sign, freshness, time skew)
   - `setFeed()` — no validation that the new feed is a functioning Chainlink feed
   - What happens to all vault positions if maxDelay is set to a very large value

4. **`src/core/NXUSDToken.sol`** — Least complex. Focus on:
   - Role guards on `mint()` / `burn()`
   - `setMinter()` / `setBurner()` accessibility

### Public Surfaces

| Surface | URL / Location | Notes |
|---|---|---|
| Protocol status API | `/api/status` | Live chain state. `verdict_source: "simplified_runtime"`. |
| Vault API | `/api/vaults` | Per-vault collateral, debt, CR, status. |
| Audit receipts | `/api/receipts` | Canonical engine verdicts. SHA-256 hashed. |
| Receipts repo | `github.com/NEXUS120-Official/nexus-receipts` | Public, immutable receipt packages. |
| Contracts repo | `github.com/NEXUS120-Official/nexus-contracts` | Source + scripts + broadcast receipts. |
| Arbiscan | `sepolia.arbiscan.io` | All contracts are verified. |

### Existing Evidence

- **Forge broadcast receipts** — `broadcast/DeployCoreHardened.s.sol/421614/run-latest.json`
  and adjacent files record all deploy and configuration transactions with full call data.
- **Governance migration receipts** — `broadcast/GovernanceMigrationScenario.s.sol` and
  `GovernanceRevokeScenario.s.sol` document the role transfer sequence from deployer EOA
  to Safe multisig.
- **Safe execution receipts** — `SafeExecSetFeed` and `SafeExecGrantVaultKeeper` broadcasts
  confirm that governance actions now flow through the multisig.
- **NEXUS-120 Engine receipts** — Hourly packages at `/api/receipts` with SHA-256 integrity
  hashes. Provide a continuous audit trail of protocol state.

### What Is Not Yet Done

| Item | Status |
|---|---|
| Formal test coverage report | Not produced. Tests exist but coverage is unquantified. |
| GUARDIAN_ROLE separation | Documented in `GUARDIAN_SEPARATION_PLAN.md`; not yet executed on-chain. |
| On-chain supply cap enforcement | Reference contract exists; not deployed or integrated. |
| SOV_003 / SOV_005 engine logic audit | No independent review of the Python capital adequacy and risk lattice logic. |
| Mainnet oracle configuration | Testnet feed addresses and maxDelay values are testnet-appropriate. Mainnet parameters not determined. |
| Multi-collateral architecture | Not designed. Single WETH collateral is a fundamental constraint of the current system. |
| Formal security audit | This document is preparation material, not a completed audit. |

### Recommended First Questions for an Auditor

1. Can a malicious `setOracle()` call (via a compromised Safe) drain all collateral?
   What is the minimum threshold of Safe signers required to execute this?
2. Is there a reentrancy path in `VaultManager.liquidate()` given the ERC-20 transfer
   order relative to state mutations?
3. Does the close factor cap in LiquidationEngine correctly prevent full liquidation
   in a single call for any debt size?
4. Can a vault be left with zero collateral and non-zero debt after a sequence of operations?
5. Is the NXUSD burn in `VaultManager.burn()` correctly protected from callers who do
   not hold the tokens they are burning?

---

## APPENDIX A — Deploy Parameters (Confirmed from Broadcast)

| Parameter | Value | Source |
|---|---|---|
| `OracleModule.maxDelay` | 3600 seconds | Constructor arg in broadcast |
| `VaultManager.minCollateralRatioBps` | 15000 (150%) | Constructor arg in broadcast |
| `VaultManager.liquidationRatioBps` | 13000 (130%) | Constructor arg in broadcast |
| `VaultManager.maxDelay` | 3600 seconds | Constructor arg in broadcast |
| `LiquidationEngine.closeFactorBps` | 5000 (50%) | Constructor arg in broadcast |
| Admin (at deploy) | `0xB4518cebFf8a92A8514f90F21B86e7Cb987F4ab6` | Broadcast `from` field |

---

## APPENDIX B — Source File Map

```
src/
  core/NXUSDToken.sol           — Protocol stablecoin
  oracle/OracleModule.sol       — Chainlink wrapper with freshness validation
  vault/VaultManager.sol        — Core vault state and CR enforcement
  vault/LiquidationEngine.sol   — Keeper-facing liquidation interface

constitution/
  constitution_engine.sol       — Reference invariant contract (NOT deployed)

test/
  VaultManager.t.sol
  LiquidationEngine.t.sol
  NXUSDToken.t.sol
  OracleModule.t.sol
  VaultPause.t.sol
  LiquidationPause.t.sol
  mocks/MockAggregatorV3.sol
  mocks/MockERC20.sol

script/
  DeployCoreHardened.s.sol      — Canonical production deploy script
  SafeExecSetFeed.s.sol         — Safe-executed oracle feed switch
  SafeExecGrantVaultKeeper.s.sol — Safe-executed keeper grant
  GovernanceMigrationScenario.s.sol
  GovernanceRevokeScenario.s.sol
```

---

*This document will be updated as the audit readiness programme progresses.
Open items are marked [OPEN] throughout. Sections are version-controlled alongside
the contract source in the `nexus-contracts` repository.*
