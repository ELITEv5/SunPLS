# GoldPool — Reserve Layer Build Plan
*Technical synthesis: architecture improvements + ecosystem integration roadmap*

---

## Overview

GoldPool is a permanent, publicly auditable proof-of-commitment layer for PulseBitcoin. The goal of this build plan is to elevate it from a standalone vault experiment into the **bedrock reserve layer of the PulseChain ecosystem** — serving SunPLS/ProjectUSD, lending markets, and derivative protocols as a non-liquidatable, structurally stable collateral base.

---

## Phase 0 — Foundations
> Nothing else starts until this is done.

### 0.1 Define the Integration Target Stack

Decide which protocols GoldPool will serve as reserve layer for at launch. The minimum viable set:

- **SunPLS** — natural first integration, controlled environment
- **One lending market** — existing or purpose-built
- **PulseX LP** — for PBTCG tradeable liquidity from day one

Everything downstream depends on knowing exactly what PBTCG needs to *do* in these systems. Define collateral interface requirements before writing a line of GoldPool code.

### 0.2 Lock the Token Economic Parameters

The whitepaper leaves key numbers vague. These must be finalized before deployment — the contract is immutable:

| Parameter | Notes |
|---|---|
| Gold quota percentage | 10% stated — stress test before committing |
| Minimum deposit size | Prevents dust attacks |
| All four activation thresholds | Exact on-chain values |
| Continuous transformation rate | Blocks per micro-conversion if implementing Ch. 28a |
| PBTCG minting formula | Exact tokens per PBTC deposited |

Run spreadsheet simulations across multiple price scenarios before committing any of these to immutable code.

### 0.3 Choose and Audit the Gold Reserve Asset

This decision cascades into activation event logic and cannot be deferred.

| Option | Pros | Cons |
|---|---|---|
| PAXG / Tether Gold | Gold narrative intact | Custodian risk, regulatory exposure |
| PLS | Natively on-chain, no custodian | Correlation risk with PBTC |
| Basket (PLS + stable + commodity) | Diversified risk | More complex implementation |
| Decentralized stable asset | Dollar-stable sizing, oracle-free | Less compelling narrative |

Model the failure scenario for whichever option is chosen. Document it explicitly — do not bury it in a risk footnote.

---

## Phase 1 — Contract Architecture
> Build the vault and token correctly once.

### 1.1 Core Vault Contract

Single immutable contract. Exactly these functions and nothing else:

```solidity
deposit(uint256 pbtcAmount) external
getVaultBalance() public view returns (uint256 pbtc, uint256 gold)
getNAV() public view returns (uint256 navPerPBTCG)
getDiscount() public view returns (int256 premiumOrDiscount)
```

**No admin functions. No upgrade proxy. No owner.**

Encode invariant assertions as runtime checks on every state-changing function:

```solidity
// After every deposit or activation:
assert(boundPBTC >= previousBoundPBTC);
assert(totalVaultValue >= 0);
assert(goldReserve >= 0);
```

These turn documented mathematical claims into on-chain guarantees. If any invariant is ever violated — by bug or edge case — the transaction reverts rather than corrupting state.

### 1.2 PBTCG Token Contract

Standard ERC20 with one hardcoded constraint: minting is callable **only** by the vault contract address, set at deployment. No other mint path exists. Make this verifiable at the bytecode level.

Simultaneously mint a **receipt NFT (ERC721)** recording:

- Deposit amount
- Block timestamp
- Running bound supply at time of deposit
- Sequential deposit index (deposit #1, #2, etc.)

Early deposit NFTs become provenance artifacts. Genesis depositors are permanently identified on-chain.

### 1.3 Activation Module

Deploy as a **separate contract** authorized by the vault at deployment. Separation matters:

- Activation logic carries more attack surface — isolate it
- Core vault audit scope stays clean and cheap
- Governance can be applied to the activation module without touching the vault

The activation module has one permission: instruct the vault to convert a specified gold amount to PBTC and bind it. The vault verifies the conversion before updating state.

### 1.4 Continuous Transformation (Chapter 28a)

If implementing, this lives in the activation module as a **permissionless public function**:

```solidity
triggerContinuousTransform() external
```

Anyone can call it. The function checks if enough blocks have passed since last call, calculates the micro-conversion amount, executes it. No governance, no keeper required. Callers can receive a tiny gas rebate from a fee pool if needed to ensure reliable triggering.

### 1.5 NAV Oracle Function

Pure `view` function. Zero cost to call. Returns current intrinsic value per PBTCG based on vault state plus externally provided price inputs. The function takes prices as parameters — the caller provides them — so the vault remains oracle-free while the NAV calculation is standardized and auditable.

Third-party dashboards, lending protocols, and aggregators all get a clean reference point without any oracle dependency in the core system.

---

## Phase 2 — Audit and Formal Verification
> Non-negotiable. Budget and timeline accordingly.

### 2.1 Select Auditors

Minimum **two independent audits** from firms with immutable contract experience. Auditors must explicitly sign off on:

- All invariants hold under all reachable states
- No reentrancy paths exist
- Minting occurs only via the correct deposit path
- No admin extraction path exists even through obscure call chains

### 2.2 Formal Verification

Use Certora Prover or equivalent to verify core invariants as mathematical proofs, not test coverage.

**Four non-negotiable properties to verify formally:**

1. `boundPBTC` is monotonically non-decreasing
2. No function reduces `goldReserve` except authorized activation
3. PBTCG total supply never exceeds deposits times minting ratio
4. No ETH or token outflow path exists to any address

### 2.3 Simulation Suite

Before audit, build a simulation running:

- 10,000 random deposit sequences
- All four activation trigger conditions
- Edge cases: zero price, max `uint256` amounts, rapid sequential deposits
- Griefing attempts: dust deposits, failed gold conversions, re-entrancy attempts

Catches bugs before they cost audit dollars. Identifies parameter edge cases before immutable deployment.

---

## Phase 3 — Integration Engineering
> This is where GoldPool becomes the reserve layer rather than a standalone product.

### 3.1 SunPLS Integration

Add PBTCG as an accepted collateral type in SunPLS:

- Build a PBTCG price feed for the SunPLS oracle using the NAV function plus market price, taking the **lower of the two** (conservative valuation)
- Set collateralization ratio appropriate for PBTCG's volatility profile — likely 200%+ given no redemption floor
- Add PBTCG to the SunPLS frontend collateral selector

**The resulting loop:**
> Deposit PBTC into GoldPool → receive PBTCG → post PBTCG as collateral → borrow SunPLS stable asset

This is the first concrete use case. It creates demand for PBTCG that is independent of speculation on vault NAV.

### 3.2 PulseX Liquidity Bootstrapping

Seed a PBTCG/PLS pool at deployment. Options:

- Allocate 1-2% of early deposits to LP seeding (requires pre-launch governance agreement)
- Raise a small treasury pre-launch specifically for LP seeding
- Partner with an existing liquidity provider in exchange for genesis NFT recognition

Without this, PBTCG has no market price, the discount oracle returns nothing useful, and the SunPLS integration has no price reference.

### 3.3 Lending Market Integration

Either integrate with an existing PulseChain lending market or build a minimal purpose-specific lending module:

- Accept PBTCG as collateral
- Issue stable asset loans against it
- Use **internal redistribution on default** — no market liquidation, as designed in Chapter 40
- Set liquidation threshold conservatively given PBTCG's NAV floor logic

This is the second demand driver for PBTCG beyond pure speculation.

---

## Phase 4 — Dashboard and Data Layer
> The proof-of-work surface. This is the product people actually interact with.

### 4.1 Real-Time Vault Dashboard

Static frontend reading public RPC — no backend, no server, no failure point.

**Displays:**

- Total PBTC permanently bound (absolute + % of max supply)
- Current NAV per PBTCG
- PBTCG market price (from PulseX)
- Current premium or discount to NAV
- Gold reserve value
- Activation event history with dates and amounts
- Days since deployment
- Market cycles survived (PBTC price drawdown/recovery events above a defined threshold)
- Deposit leaderboard by NFT index (shows genesis depositors)

### 4.2 NAV API Endpoint

Expose the NAV calculation as a simple public API. Any protocol wanting to use PBTCG as collateral gets a standardized price reference without implementing the NAV calculation themselves. Makes PBTCG composable across the ecosystem.

### 4.3 Milestone Communication

Every time a significant threshold is crossed, surface it publicly:

- 1% of PBTC supply permanently bound
- First activation event executed
- 1 year operational without incident
- First external protocol integration live

The dashboard is the artifact. The milestones are the narrative.

---

## Phase 5 — Launch Sequence
> Order matters. Each step enables the next.

```
1.  Audit complete and published publicly
2.  Deploy vault contract — verify on-chain, publish source
3.  Deploy PBTCG token — verify minting restriction
4.  Deploy activation module — verify authorization scope
5.  Seed PulseX LP
6.  Open deposits
7.  Activate SunPLS collateral integration
8.  Launch dashboard
9.  Activate lending module
10. Begin continuous transformation if implemented
```

Steps 1–4 happen in a single coordinated deployment sequence.  
Steps 5–10 can be staggered over days to weeks.

---

## Phase 6 — Governance Transition
> Progressively reduce human control as the system proves itself.

| Phase | Control Model | Trigger to Advance |
|---|---|---|
| Early | Multisig controls activation parameters and gold quota | System operational, first audit cycle complete |
| Middle | PBTCG holders vote on parameter changes (supermajority + time-delay) | Sufficient PBTCG distribution achieved |
| Mature | Continuous transformation handles all growth autonomously | Bound supply exceeds defined % of max supply |
| Final | Governance votes become rare — system runs without human input | Multisig dissolves per pre-committed roadmap |

**Key constraint:** No governance decision may ever extract value from the vault or lift the binding rule. Governance controls only the outer system layer.

The governance transition itself should be pre-committed in a public roadmap with **specific trigger conditions** — not calendar dates, but system maturity metrics.

---

## Architectural Improvements Summary

| Improvement | Priority | Phase |
|---|---|---|
| Replace gold component with cleaner reserve asset | High | Phase 0 |
| Continuous micro-transformation (Ch. 28a) | High | Phase 1 |
| On-chain NAV view function | High | Phase 1 |
| Invariants as runtime assertions | High | Phase 1 |
| Receipt NFT for genesis depositors | Medium | Phase 1 |
| Two-auditor formal verification | Critical | Phase 2 |
| PBTCG as SunPLS collateral | High | Phase 3 |
| PulseX LP seed at launch | High | Phase 3 |
| Lending module integration | Medium | Phase 3 |
| Real-time vault dashboard | High | Phase 4 |
| Public NAV API | Medium | Phase 4 |

---

## Critical Path

If resources are constrained, the minimum viable sequence that makes the synthesis real:

```
Vault contract → Audit → SunPLS integration → PulseX LP seed → Dashboard
```

This five-step sequence is sufficient to establish GoldPool as a genuine reserve layer rather than a standalone token experiment. Everything else follows once the core loop is proven.

---

## The Single Biggest Risk

**It is not technical.**

The architecture is coherent. The invariants are real. The code can be made correct.

The risk is whether PBTCG finds enough organic demand to make the SunPLS collateral integration worth using. That means the ecosystem development work — making the case to PBTC holders that locking into GoldPool is worth it — must start immediately and run in parallel with every technical phase above.

The vault is a mechanism. Demand is a narrative. Both need to be built at the same time.

---

*Document version 1.0 — synthesized from GoldPool Whitepaper VB (January 2026) and technical assessment*
