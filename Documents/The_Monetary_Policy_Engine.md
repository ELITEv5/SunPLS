# SunPLS Monetary Policy

SunPLS implements a deterministic **algorithmic monetary policy** designed to stabilize the value of SunPLS relative to its collateral asset (PLS).

Instead of relying on discretionary decisions or governance votes, SunPLS uses a **feedback control system** implemented on-chain.

This design is conceptually inspired by the **ProjectUSD Controller specification**, which describes a feedback-driven monetary system where interest rates adjust based on deviations between market price and equilibrium price.

SunPLS adopts this core concept while simplifying the overall architecture.

---

# Core Economic Variables

The SunPLS monetary policy system operates using four key variables.

| Variable | Meaning |
|--------|--------|
| `P` | Observed market price of SunPLS |
| `R` | Internal equilibrium price |
| `ε` | Price deviation (`P − R`) |
| `r` | System borrowing rate |

These variables define the economic state of the system.

---

# Controller Feedback Equation

The controller implements a proportional feedback mechanism.

```
ε = P − R

Δr = K × (ε / R)

r_next = r_current + Δr
```

Where:

| Parameter | Description |
|-----------|-------------|
| `K` | controller gain coefficient |
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

SunPLS is trading above the equilibrium price.

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

SunPLS is trading below the equilibrium price.

Controller response:

```
r decreases
```

Effects:

- borrowing becomes cheaper  
- minting increases  
- supply expands  
- market price rises toward equilibrium

---

# Deadband Filter

Financial markets contain noise and short-term volatility.

To prevent unnecessary rate adjustments, the controller implements a **deadband region**.

```
|P − R| / R ≤ Deadband
```

When the deviation remains within the deadband range, the controller performs **no rate change**.

This prevents the system from reacting to small price fluctuations.

---

# Rate Limiter

Large policy changes can destabilize a system.

To prevent abrupt interest rate changes, the controller enforces a **rate limiter**.

```
|Δr| ≤ δr_max
```

Where:

```
δr_max = maximum rate change per epoch
```

This ensures that monetary policy evolves smoothly.

---

# Equilibrium Price Adjustment

The equilibrium price `R` is allowed to adjust slowly toward the observed market price.

```
R_next = R + α(P − R)
```

Where:

| Parameter | Meaning |
|-----------|--------|
| `α` | damping factor |

This allows the equilibrium price to adapt gradually while avoiding sudden shifts.

Additional safety:

```
|ΔR| ≤ 10% per epoch
```

This prevents rapid equilibrium changes.

---

# Oracle Dependence

The controller requires a price signal from the oracle.

SunPLS therefore includes **multiple oracle degradation modes** to maintain safe operation during oracle failures.

| Mode | Behavior |
|------|---------|
| Mode A | fresh oracle update |
| Mode B | fallback price using `peek()` |
| Mode C | stored last known price |
| Mode D | freeze controller if no valid price |

These modes ensure the system continues operating safely even if oracle updates temporarily fail.

---

# Dynamic Controller Gain

When oracle price data becomes stale, the controller reduces its responsiveness.

```
effectiveK = K × (1 − age / MAX_P_AGE)
```

Where:

| Parameter | Meaning |
|-----------|--------|
| `age` | time since last fresh oracle update |

This prevents aggressive policy adjustments based on outdated market data.

---

# Emergency Protection

The controller includes an emergency safety mechanism.

If vault health across the system drops below a defined threshold:

```
r = MAX_RATE
```

This forces borrowing costs to increase rapidly, encouraging:

- debt repayment
- deleveraging
- system risk reduction

---

# Epoch Execution

The controller executes once per epoch.

Typical epoch duration:

```
3600 seconds (1 hour)
```

Epoch sequence:

1. retrieve market price from oracle  
2. compute price deviation `ε`  
3. apply deadband filter  
4. compute rate change `Δr`  
5. apply rate limiter  
6. update borrowing rate `r`  
7. adjust equilibrium price `R` (if fresh price available)  
8. emit telemetry events  

---

# Telemetry Metrics

The controller records operational statistics to monitor system behavior.

| Metric | Purpose |
|------|--------|
| `limiterHits` | measures controller pressure |
| `deadbandSkips` | tracks noise filtering |
| `oracleFallbacks` | monitors oracle reliability |
| `frozenEpochs` | detects oracle outages |
| `emergencyEpochs` | records stress events |

These metrics allow public monitoring of the protocol’s health.

---

# Economic Goal

The goal of the SunPLS monetary policy is to ensure:

```
P → R
```

Over time, the market price should converge toward the equilibrium price.

This convergence occurs through:

- supply incentives
- borrowing costs
- redemption arbitrage
- liquidation pressure

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
market price signal
↓
controller algorithm
↓
automatic rate adjustment
```

Monetary policy becomes transparent and predictable.

---

# Limitations

SunPLS monetary policy stabilizes the **relative value between SunPLS and PLS**.

It does not stabilize the external value of PLS itself.

Therefore:

- PLS volatility still affects collateral values
- extreme market conditions may temporarily widen price deviations

However, the system’s feedback loop attempts to restore equilibrium over time.

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
