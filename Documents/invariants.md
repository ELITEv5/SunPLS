# SunPLS Protocol Invariants

This document defines the core invariants that the SunPLS protocol must maintain at all times.

An invariant is a condition that must **always remain true**, regardless of market conditions or user behavior.

These guarantees are enforced by smart contract logic and are essential to maintaining the safety and solvency of the system.

The SunPLS design is inspired by the feedback stabilization model described in the **ProjectUSD specifications**, but implemented with a simplified architecture.

---

# Controller Invariants

## I1 — Rate Bounds

The borrowing rate must remain within predefined limits at all times.

```
MIN_RATE ≤ r ≤ MAX_RATE
(-5% APR ≤ r ≤ 20% APR)
```

Purpose:

- prevents extreme interest rate conditions
- ensures predictable borrowing incentives
- negative floor preserves autonomous recovery capability

---

## I2 — Rate Change Limiter

The change in borrowing rate per epoch is bounded.

```
|Δr| ≤ DELTA_R_MAX (0.05% per epoch)
```

Purpose:

- prevents sudden monetary policy shocks
- ensures gradual system adjustment

---

## I3 — Equilibrium Value Minimum Bound

R must never fall below a minimum value.

```
R ≥ R_FLOOR (1e18)
```

Purpose:

- prevents division-by-zero errors in redemption arithmetic
- protects redemption calculations from collapse

---

## I4 — Bounded Equilibrium Movement

The equilibrium value may only move within a limited range per epoch.

```
|ΔR| ≤ R × MAX_R_MOVE_BPS / 10000  (10% per epoch)
```

Purpose:

- prevents abrupt equilibrium shifts
- stabilizes redemption behavior over time

---

## I5 — R Freshness

R may only update when the oracle provides a fresh price (Mode A).

```
R updates only when oracle.update() returns P > 0
```

Purpose:

- prevents R from drifting based on stale or fabricated price data
- ensures equilibrium reflects actual market conditions

---

## I6 — Oracle Failure Liveness

Oracle failure must not permanently halt protocol operation.

Controller behavior during failure:

```
Mode B: K decayed, R frozen, epoch advances
Mode C: K decayed further, R frozen, epoch advances
Mode D: rate frozen, epoch advances
```

Purpose:

- ensures system liveness under oracle disruption
- prevents protocol shutdown due to temporary oracle outages
- epoch counter always increments

---

## I7 — Controller Determinism

For a given price input P, the controller produces a deterministic rate output.

```
same P → same r
```

Purpose:

- ensures predictable monetary policy
- no randomness, no governance override, no hidden state

---

## I8 — Vault Failure Non-Fatal

A vault contract revert during `updateRate()` must not block epoch execution.

```
try vault.updateRate(r) {} catch { emit VaultUpdateFailed(...) }
```

Purpose:

- epoch always completes regardless of vault behavior
- system liveness preserved even under vault-side failures

---

# Vault Invariants

## I9 — Vault Solvency

All SunPLS may only be minted against sufficient collateral.

```
CR ≥ COLLATERAL_RATIO (150%) to mint or withdraw
```

Where:

```
CR = (collateral × 1e18 × 100) / (debt × price)
```

Purpose:

- ensures SunPLS is always overcollateralized at issuance
- prevents undercollateralized minting

---

## I10 — Liquidation Eligibility

Vaults may only be liquidated when their collateral ratio falls below the liquidation threshold.

```
CR < LIQUIDATION_RATIO (110%)
```

Purpose:

- prevents false liquidations of healthy vaults
- ensures fair enforcement of safety rules

---

## I11 — Redemption Eligibility

Vaults may only be redeemed against when their collateral ratio is at or below the redemption threshold.

```
CR ≤ REDEMPTION_RATIO (130%)
```

Vaults above 130% CR are completely immune to redemption.

Purpose:

- protects healthy vault owners from involuntary exits
- concentrates redemption pressure on genuinely distressed positions
- eliminates redemption-then-liquidation attack vector against healthy vaults

---

## I12 — Redemption Collateral Safety

Redemptions must never cause vault collateral to become negative.

```
plsOut ≤ vault.collateral
```

Purpose:

- ensures vault accounting consistency
- prevents underflow conditions

---

## I13 — Debt Initialization

`lastDebtAccrual` must always be set on first debt issuance.

```
if vault.debt == 0: lastDebtAccrual = block.timestamp
```

Purpose:

- prevents incorrect interest accrual calculations
- ensures elapsed time is always measured from a valid anchor

---

## I14 — Dutch Auction Anchor

The liquidation bonus elapsed time is measured from when the vault first became undercollateralized, not from the liquidation call.

```
elapsed = block.timestamp − undercollateralizedSince
```

Purpose:

- ensures liquidation bonus reflects true vault distress duration
- prevents manipulation of auction timing

---

## I15 — Bad Debt Tracking

When liquidation collateral is insufficient to cover the reward, the deficit is recorded rather than silently absorbed.

```
if reward > vault.collateral:
    deficit = reward − vault.collateral
    badDebt += deficit
    emit BadDebtRecorded(...)
```

Purpose:

- ensures bad debt is never hidden
- provides transparency for system health monitoring

---

## I16 — Redemption-Liquidation Gap

A vault cannot be liquidated within REDEMPTION_LIQUIDATION_GAP (5 minutes) of being redeemed against.

```
block.timestamp > vault.lastRedemptionTime + REDEMPTION_LIQUIDATION_GAP
```

Purpose:

- gives vault owners time to respond after redemption
- prevents atomic redemption → liquidation griefing attacks

---

## I17 — Oracle Price Fallback

The vault always maintains a `lastOraclePrice` fallback.

```
lastOraclePrice > 0 always after construction
```

Purpose:

- dead oracle never bricks deposit, repay, or withdraw operations
- system remains live regardless of oracle state

---

## I18 — Vault Latch Immutability

The vault address in both Token and Controller is set exactly once via `setVault()` and cannot be changed afterward.

```
vaultSet = true  →  setVault() reverts for all future callers
```

Purpose:

- post-latch security equivalent to immutable constructor parameter
- no privileged actor can redirect mint/burn or rate updates after latch

---

# System Safety Guarantees

These invariants collectively enforce the following guarantees:

- SunPLS is always minted against overcollateralized positions (I9)
- monetary policy evolves smoothly and predictably (I1, I2, I7)
- equilibrium value R is stable and anchored to fresh price data (I3, I4, I5)
- liquidations maintain solvency without false triggers (I10)
- redemptions target only distressed vaults, protecting healthy ones (I11, I12)
- oracle and vault disruptions cannot halt the protocol (I6, I8)
- bad debt is tracked transparently rather than silently absorbed (I15)
- vault owners have protected response windows after redemption (I16)
- the system remains fully immutable and admin-free post-latch (I18)

---

# Monitoring Invariants

The following on-chain variables allow public verification of system health:

**Controller:**
- `R` — equilibrium value
- `r` — current borrowing rate
- `epochCount` — total epochs executed
- `limiterHits` — rate limiter saturation events
- `oracleFallbacks` — degraded oracle epochs
- `deadbandSkips` — epochs where P was within deadband of R
- `frozenEpochs` — Mode D epochs (no valid price)
- `emergencyEpochs` — epochs where emergency rate was forced

**Vault:**
- `totalCollateral` — total PLS held across all vaults
- `totalDebt` — total SunPLS outstanding
- `badDebt` — accumulated unrecovered liquidation deficit
- `systemHealth()` — system-wide collateralization ratio
- `currentRate` — active interest rate from controller

These values allow researchers and users to monitor system behavior and verify invariant compliance in real time.

---

# Summary

The SunPLS protocol relies on a clearly defined set of invariants spanning both the Controller and Vault contracts.

By enforcing strict bounds on rates, equilibrium movement, liquidation eligibility, and redemption targeting, the system ensures that SunPLS remains solvent, predictable, and manipulation-resistant under a wide range of market conditions.

These invariants form the mathematical and contractual foundation of the protocol's autonomous monetary design.

---

# References

ProjectUSD Controller Specification  
ProjectUSD Stability Model Research  
Control Theory Applications in Financial Systems
