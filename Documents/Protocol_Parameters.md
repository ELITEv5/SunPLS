# SunPLS Protocol Parameters

This document lists and explains the core parameters governing the SunPLS protocol.

All parameters are embedded directly in the deployed contracts and define the economic and safety behavior of the system.

SunPLS intentionally minimizes the number of tunable parameters in order to reduce governance complexity and make the system easier to reason about.

Many parameters are inspired by the **ProjectUSD specification**, which proposes a feedback-based monetary policy driven by price deviations.

---

# Monetary Policy Parameters

These parameters define the behavior of the SunPLS Controller.

---

## K — Controller Gain

```
K = 1e15
```

Meaning:

Controller sensitivity to price deviations.

Higher values cause the controller to react more aggressively to price movements.

Controller equation:

```
Δr = K × (ε / R)
```

Where:

```
ε = P − R
```

Typical interpretation:

```
1% price deviation → ~0.1% rate adjustment
```

This produces a moderate stabilization response.

---

## ALPHA — Equilibrium Damping

```
ALPHA = 5e15
```

Meaning:

Rate at which the equilibrium price `R` moves toward the observed market price.

Equation:

```
R_next = R + α(P − R)
```

This prevents sudden shifts in the equilibrium price and smooths long-term adjustments.

---

## DEADBAND — Noise Filter

```
DEADBAND = 1e15
```

Equivalent to:

```
0.1%
```

Meaning:

Small price fluctuations within this range are ignored by the controller.

Condition:

```
|P − R| / R ≤ DEADBAND
```

When this condition holds:

```
Δr = 0
```

This prevents unnecessary policy adjustments caused by normal market noise.

---

## DELTA_R_MAX — Rate Limiter

```
DELTA_R_MAX = 5e14
```

Equivalent to:

```
0.05% per epoch
```

Meaning:

Maximum rate change allowed per epoch.

Limiter rule:

```
|Δr| ≤ DELTA_R_MAX
```

This prevents abrupt monetary policy changes that could destabilize borrowing incentives.

---

# Rate Bounds

The system enforces hard limits on borrowing rates.

---

## MIN_RATE

```
MIN_RATE = -5e16
```

Equivalent to:

```
-5%
```

Meaning:

The lowest possible borrowing rate.

Negative rates may encourage borrowing and increase supply if SunPLS trades below equilibrium.

---

## MAX_RATE

```
MAX_RATE = 20e16
```

Equivalent to:

```
20%
```

Meaning:

The highest possible borrowing rate.

High rates discourage borrowing and reduce supply expansion.

---

# Epoch Parameters

The controller operates in discrete time intervals called epochs.

---

## EPOCH_DURATION

```
EPOCH_DURATION = 3600 seconds
```

Meaning:

Controller updates occur once every hour.

Each epoch performs:

```
price retrieval
deviation calculation
policy update
rate adjustment
```

Epoch-based updates prevent excessive policy reactions.

---

# Equilibrium Price Constraints

The equilibrium price `R` defines the internal system exchange rate between SunPLS and PLS.

---

## R_FLOOR

```
R_FLOOR = 1e18
```

Meaning:

Minimum equilibrium price allowed by the system.

This prevents division-by-zero errors and ensures redemption logic remains safe.

---

## MAX_R_MOVE_BPS

```
MAX_R_MOVE_BPS = 1000
```

Equivalent to:

```
10% per epoch
```

Meaning:

Maximum allowed movement of `R` per epoch.

Rule:

```
|ΔR| ≤ 10%
```

This prevents large equilibrium shifts that could destabilize the system.

---

# Oracle Safety Parameters

These parameters define how the protocol behaves when oracle price data becomes stale.

---

## MAX_P_AGE

```
MAX_P_AGE = 24 hours
```

Meaning:

Maximum acceptable age of a stored price.

If the oracle price becomes older than this threshold:

```
controller gain decays toward zero
```

Eventually:

```
controller freezes policy updates
```

This prevents decisions based on outdated price data.

---

# Emergency Safety Parameter

---

## EMERGENCY_HEALTH_THRESHOLD

```
EMERGENCY_HEALTH_THRESHOLD = 120
```

Meaning:

System health threshold below which emergency measures activate.

If vault health falls below this level:

```
controller forces r = MAX_RATE
```

This encourages rapid deleveraging and risk reduction.

---

# Telemetry Counters

The protocol tracks several operational statistics.

These values help monitor system behavior over time.

---

## limiterHits

Number of epochs where the rate limiter was triggered.

High values may indicate strong controller pressure.

---

## deadbandSkips

Number of epochs where price deviation fell within the deadband.

High values indicate stable market conditions.

---

## oracleFallbacks

Number of epochs where oracle fallback modes were used.

This metric measures oracle reliability.

---

## frozenEpochs

Number of epochs where no valid price was available.

The controller freezes policy updates during these events.

---

## emergencyEpochs

Number of times the controller activated emergency rate protection.

This indicates severe system stress.

---

# Parameter Philosophy

SunPLS deliberately keeps the parameter set small.

Goals:

- easier economic analysis
- reduced governance risk
- lower implementation complexity
- predictable system behavior

This approach aligns with the **minimal autonomous protocol design philosophy**.

---

# Parameter Transparency

All parameters are visible on-chain through the Controller contract.

Anyone can query:

```
getParameters()
```

This transparency ensures the protocol's economic rules are publicly verifiable.

---

# Parameter Summary

| Parameter | Purpose |
|-----------|---------|
| K | controller sensitivity |
| ALPHA | equilibrium damping |
| DEADBAND | noise filtering |
| DELTA_R_MAX | rate limiter |
| MIN_RATE | minimum borrowing rate |
| MAX_RATE | maximum borrowing rate |
| EPOCH_DURATION | policy update interval |
| R_FLOOR | minimum equilibrium price |
| MAX_R_MOVE_BPS | max equilibrium adjustment |
| MAX_P_AGE | oracle freshness threshold |
| EMERGENCY_HEALTH_THRESHOLD | system stress protection |

---

# References

Conceptual inspiration:

ProjectUSD Whitepaper  
ProjectUSD Controller Specification  
Feedback Control Systems in Monetary Policy
