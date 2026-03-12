# SunPLS Monetary Policy

SunPLS implements a deterministic **algorithmic monetary policy** designed to stabilize the value of SunPLS relative to its collateral asset (PLS).

Instead of relying on discretionary decisions or governance votes, SunPLS uses a **feedback control system** implemented on-chain.

This design is conceptually inspired by the **ProjectUSD Controller specification**, which describes a feedback-driven monetary system where interest rates adjust based on deviations between market price and equilibrium value.

SunPLS adopts this core concept while simplifying the overall architecture.

---

# Core Economic Variables

The SunPLS monetary policy system operates using four key variables.

| Variable | Meaning |
|--------|--------|
| `P` | Observed market price of SunPLS (WPLS per SunPLS) |
| `R` | Internal equilibrium value (WPLS per SunPLS) |
| `ε` | Normalized price deviation (`\|P − R\| / R`) |
| `r` | System borrowing rate |

These variables define the economic state of the system.

---

# Controller Feedback Equation

The controller implements a proportional feedback mechanism.

```
ε = |P − R| / R

Δr = K × ε

r_next = r_current + Δr  (subject to rate limiter and bounds)
```

Where:

| Parameter | Description |
|-----------|-------------|
| `K` | controller gain coefficient (1e15 = 0.1%) |
| `ε` | normalized deviation (absolute, dimensionless) |
| `Δr` | rate change for the epoch |
| `r` | borrowing rate applied to vault debt |

The controller runs once per **epoch** and updates the borrowing rate accordingly.

---

# Policy Behavior

## Case 1 — Market Price Above Equilibrium

```
P > R
```

Meaning:

SunPLS is trading above the equilibrium value.

Controller response:

```
r increases
```

Effects:

- borrowing becomes more expensive
- minting slows
- supply growth decreases
- market price falls toward equilibrium

---

## Case 2 — Market Price Below Equilibrium

```
P < R
```

Meaning:

SunPLS is trading below the equilibrium value.

Controller response:

```
r decreases
```

Effects:

- borrowing becomes cheaper
- minting increases
- supply expands
- market price rises toward equilibrium

At the floor (MIN_RATE = −5% APR), negative rates reduce vault debt over time — the last autonomous recovery tool when redemption liquidity is exhausted.

---

# Deadband Filter

Financial markets contain noise and short-term volatility.

To prevent unnecessary rate adjustments, the controller implements a **deadband region**.

```
ε = |P − R| / R ≤ DEADBAND (0.1%)
```

When the deviation remains within the deadband range, the controller performs **no rate change**.

This prevents the system from reacting to small price fluctuations.

---

# Rate Limiter

Large policy changes can destabilize a system.

To prevent abrupt interest rate changes, the controller enforces a **rate limiter**.

```
|Δr| ≤ DELTA_R_MAX (0.05% per epoch)
```

This ensures that monetary policy evolves smoothly even during large price deviations. When the limiter fires, `limiterHits` is incremented.

---

# Equilibrium Value Adjustment

The equilibrium value `R` is allowed to adjust slowly toward the observed market price.

```
ΔR = ALPHA × (P − R)
```

Where:

| Parameter | Meaning |
|-----------|--------|
| `ALPHA` | damping factor (5e15 = 0.5%) |

This allows the equilibrium value to adapt gradually while avoiding sudden shifts.

Additional safety:

```
|ΔR| ≤ R × 10% per epoch
```

R only moves during Mode A epochs — a fresh oracle price is required. R never moves during fallback modes.

---

# Oracle Dependence

The controller requires a price signal from the oracle.

SunPLS therefore includes **multiple oracle degradation modes** to maintain safe operation during oracle failures.

| Mode | Behavior | K | R |
|------|---------|---|---|
| Mode A | Fresh oracle update | Full K | Updates |
| Mode B | Peek fallback price | K decayed by price age | Frozen |
| Mode C | Stored last known price | K decayed further | Frozen |
| Mode D | No valid price available | 0 (rate frozen) | Frozen |

These modes ensure the system continues operating safely even if oracle updates temporarily fail. Epochs always advance — the system never permanently stalls.

---

# Dynamic Controller Gain

When oracle price data becomes stale, the controller reduces its responsiveness.

```
effectiveK = K × (MAX_P_AGE − age) / MAX_P_AGE
```

Where:

| Parameter | Meaning |
|-----------|--------|
| `age` | time since last Mode A (fresh) oracle update |
| `MAX_P_AGE` | 24 hours |

The minimum effectiveK is 1 (not zero) — this prevents division by zero downstream while still significantly reducing controller aggressiveness. Once age exceeds MAX_P_AGE, the controller enters Mode D and freezes rate updates entirely.

---

# Emergency Protection

The controller includes an emergency safety mechanism.

If vault system health drops below 120% at the start of an epoch:

```
r = MAX_RATE (20% APR)
```

This check runs before oracle resolution and cannot be bypassed by oracle failure. It forces borrowing costs to increase rapidly, encouraging:

- debt repayment
- deleveraging
- system risk reduction

---

# Epoch Execution

The controller executes once per epoch.

Epoch duration:

```
3600 seconds (1 hour)
```

Epoch sequence:

1. emergency health check — if system health < 120%, force MAX_RATE and exit
2. resolve oracle price (Mode A → B → C → D)
3. if Mode D, freeze rate and advance epoch
4. compute normalized deviation `ε = |P − R| / R`
5. apply deadband filter — if ε ≤ 0.1%, skip rate change
6. compute rate change `Δr = K × ε`
7. apply rate limiter — cap at DELTA_R_MAX
8. clamp to absolute bounds (MIN_RATE to MAX_RATE)
9. update borrowing rate `r`
10. adjust equilibrium value `R` toward P (Mode A only)
11. push rate to vault
12. emit telemetry events and advance epoch counter

---

# Telemetry Metrics

The controller records operational statistics to monitor system behavior.

| Metric | Purpose |
|------|--------|
| `limiterHits` | measures controller pressure (rate limiter saturation) |
| `deadbandSkips` | tracks noise filtering (P near R) |
| `oracleFallbacks` | monitors oracle reliability (Modes B and C) |
| `frozenEpochs` | detects complete oracle outages (Mode D) |
| `emergencyEpochs` | records systemic stress events |

All metrics are readable via `getCurrentState()` on the Controller contract.

---

# Economic Goal

The goal of the SunPLS monetary policy is to ensure:

```
P → R
```

Over time, the market price should converge toward the equilibrium value.

This convergence occurs through:

- supply incentives (rate adjustments)
- borrowing costs (positive or negative r)
- redemption arbitrage (direct price floor enforcement)
- liquidation pressure (removal of unsafe positions)

Together these mechanisms form a **closed feedback system**.

---

# Comparison with Traditional Monetary Systems

Traditional central banks operate through discretionary policy decisions.

Example structure:

```
central bank committee
↓
interest rate decision
↓
market reaction
```

SunPLS replaces this process with deterministic code:

```
market price signal (P)
↓
controller algorithm (ε, K, deadband, limiter)
↓
automatic rate adjustment (r)
↓
vault incentives
↓
supply response
```

Monetary policy becomes transparent, predictable, and manipulation-resistant.

---

# Limitations

SunPLS monetary policy stabilizes the **relative value between SunPLS and PLS**.

It does not stabilize the external value of PLS itself.

Therefore:

- PLS volatility still affects collateral values
- extreme market conditions may temporarily widen price deviations

However, the system's feedback loop attempts to restore equilibrium over time through rate adjustments, redemption arbitrage, and liquidation pressure working in parallel.

---

# Research Context

SunPLS contributes to an emerging class of financial systems sometimes described as:

**Autonomous Monetary Protocols (AMPs)**

These systems aim to implement monetary policy entirely through algorithmic rules enforced by smart contracts.

SunPLS represents an experimental implementation of these ideas in a simplified architecture inspired by ProjectUSD research.

---

# References

ProjectUSD Whitepaper V2.1  
ProjectUSD Controller Specification  
Control Theory in Financial Systems Research
