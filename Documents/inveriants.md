# SunPLS Protocol Invariants

This document defines the core invariants that the SunPLS protocol must maintain at all times.

An invariant is a condition that must **always remain true**, regardless of market conditions or user behavior.

These guarantees are enforced by smart contract logic and are essential to maintaining the safety and solvency of the system.

The SunPLS design is inspired by the feedback stabilization model described in the **ProjectUSD specifications**, but implemented with a simplified architecture.

---

# Core System Invariants

## I1 — Rate Bounds

The borrowing rate must remain within predefined limits.

```
MIN_RATE ≤ r ≤ MAX_RATE
```

Purpose:

- prevents extreme interest rate conditions
- ensures predictable borrowing incentives

---

## I2 — Rate Change Limiter

The change in borrowing rate per epoch is bounded.

```
|Δr| ≤ DELTA_R_MAX
```

Purpose:

- prevents sudden monetary policy shocks
- ensures gradual system adjustment

---

## I3 — Equilibrium Price Floor

The equilibrium price must never fall below a minimum value.

```
R ≥ R_FLOOR
```

Purpose:

- prevents division-by-zero errors
- protects redemption calculations

---

## I4 — Bounded Equilibrium Movement

The equilibrium price may only move within a limited range per epoch.

```
|ΔR| ≤ MAX_R_MOVE_BPS
```

Purpose:

- prevents abrupt equilibrium shifts
- stabilizes redemption behavior

---

## I5 — Overcollateralized Debt

All SunPLS supply must be backed by collateralized vaults.

```
Total Collateral Value ≥ Total Debt
```

Purpose:

- ensures SunPLS remains fully collateralized
- prevents system insolvency

---

## I6 — Deterministic Liquidation Eligibility

Vaults may only be liquidated when their collateral ratio falls below the liquidation threshold.

```
CR < LiquidationThreshold
```

Where:

```
CR = collateral_value / debt
```

Purpose:

- prevents false liquidations
- ensures fair enforcement of safety rules

---

## I7 — Redemption Safety

Redemptions must never cause vault collateral to become negative.

```
vault.collateral ≥ redemption_amount
```

Purpose:

- ensures vault accounting consistency
- prevents underflow conditions

---

## I8 — Oracle Dependency Isolation

The oracle provides price data but cannot directly alter system state.

Purpose:

- prevents oracle manipulation from directly affecting vault balances
- isolates external inputs from internal accounting

---

## I9 — Oracle Failure Liveness

Oracle failure must not permanently halt protocol operation.

Controller behavior during failure:

```
fallback price used
or
rate update frozen
```

Purpose:

- ensures system liveness
- prevents protocol shutdown due to oracle outages

---

## I10 — Controller Determinism

For a given price input `P`, the controller must produce a deterministic rate output.

```
same P → same r
```

Purpose:

- ensures predictable monetary policy
- prevents hidden system behavior

---

# System Safety Guarantees

These invariants collectively enforce the following guarantees:

- SunPLS remains fully collateralized
- monetary policy evolves smoothly
- vault liquidations maintain solvency
- redemptions preserve system value
- oracle disruptions cannot halt the protocol

Maintaining these invariants is critical for long-term system stability.

---

# Monitoring Invariants

The following on-chain variables allow public verification of system health:

- `R` (equilibrium price)
- `r` (borrowing rate)
- `epochCount`
- `limiterHits`
- `oracleFallbacks`
- `deadbandSkips`
- `frozenEpochs`

These telemetry values allow researchers and users to monitor system behavior in real time.

---

# Summary

The SunPLS protocol relies on a small set of clearly defined invariants to maintain stability.

By enforcing strict bounds on rates, equilibrium price movement, and liquidation eligibility, the system ensures that SunPLS remains solvent and predictable under a wide range of market conditions.

These invariants form the mathematical foundation of the protocol’s autonomous monetary design.

---

# References

ProjectUSD Controller Specification  
ProjectUSD Stability Model Research  
Control Theory Applications in Financial Systems
