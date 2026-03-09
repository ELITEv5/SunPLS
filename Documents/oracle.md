# SunPLS Oracle System

The Oracle is the **primary external data source** for the SunPLS protocol.

It provides the market price of SunPLS relative to PLS and supplies this information to the Controller and Vault system.

Because the oracle directly influences:

- vault collateral ratios
- liquidation eligibility
- redemption pricing
- monetary policy decisions

it is one of the most critical components of the protocol.

The SunPLS oracle is designed to provide reliable price data while remaining resilient to manipulation or temporary data outages.

---

# Oracle Role in the System

The oracle provides the **market price `P`** used throughout the protocol.

```
P = SunPLS market price (PLS per SunPLS)
```

This value feeds into multiple modules:

| Module | Oracle Use |
|------|-------------|
| Controller | compares market price `P` to equilibrium price `R` |
| Vault System | calculates vault collateral ratios |
| Liquidations | determines liquidation eligibility |
| Redemptions | determines collateral exchange value |

The oracle is therefore the **only external input** affecting system behavior.

---

# Price Source

The oracle retrieves price data from the SunPLS liquidity pool.

Typical sources include:

- PulseX liquidity pools
- other on-chain DEX pools
- TWAP calculations from pool reserves

By deriving the price directly from liquidity pool reserves, the oracle avoids reliance on external centralized data providers.

---

# TWAP Price Calculation

To reduce susceptibility to manipulation, the oracle typically uses a **Time-Weighted Average Price (TWAP)**.

Instead of using the latest spot price:

```
P = average price over time window
```

Example:

```
TWAP window = 30 minutes
```

Benefits of TWAP:

- reduces flash loan manipulation
- smooths short-term volatility
- increases oracle reliability

---

# Oracle Interface

The oracle exposes several key functions.

### update()

```
update() → (price, timestamp)
```

Attempts to refresh the price from the liquidity pool.

If successful:

- returns new price
- records timestamp
- updates stored price

---

### peek()

```
peek() → (price, timestamp)
```

Returns the most recently stored price without performing a new update.

This allows other contracts to read price data without triggering a state change.

---

### isHealthy()

```
isHealthy() → bool
```

Indicates whether the oracle price is considered fresh and reliable.

The controller uses this function to determine how aggressively monetary policy should react.

---

# Oracle Health

Oracle health depends on the **age of the stored price**.

Example rule:

```
price_age ≤ MAX_P_AGE
```

If the price becomes too old, the system may:

- reduce controller responsiveness
- switch to fallback modes
- temporarily freeze monetary policy

These protections prevent decisions based on stale data.

---

# Oracle Degradation Modes

To ensure the system continues functioning even during oracle problems, SunPLS implements **multiple fallback modes**.

| Mode | Description |
|-----|-------------|
| Mode A | fresh oracle update |
| Mode B | fallback using `peek()` |
| Mode C | stored last known price |
| Mode D | no usable price, system freezes rate updates |

These modes allow the protocol to degrade gracefully instead of failing entirely.

---

# Mode A — Fresh Price

```
oracle.update() returns valid price
```

Behavior:

- full controller gain applied
- equilibrium price may adjust
- system operates normally

This is the normal operating mode.

---

# Mode B — Peek Fallback

If the oracle update fails but a recent price exists:

```
oracle.peek()
```

Behavior:

- controller uses stored price
- controller gain may be reduced
- equilibrium price does not update

This allows the protocol to continue functioning during temporary oracle update issues.

---

# Mode C — Stored Price

If both update and peek fail but a previously stored price exists:

```
lastKnownPrice
```

Behavior:

- controller continues using stored price
- gain decays as price age increases

This mode provides resilience during longer oracle interruptions.

---

# Mode D — Oracle Failure

If no usable price exists:

```
P = 0
```

Behavior:

- controller rate updates freeze
- system continues operating
- vault operations remain functional

This prevents incorrect policy decisions based on invalid data.

---

# Gain Decay With Price Age

When price data becomes older, the controller reduces its responsiveness.

```
effectiveK = K × (1 − age / MAX_P_AGE)
```

Where:

| Parameter | Meaning |
|-----------|--------|
| `age` | seconds since last fresh price |
| `MAX_P_AGE` | maximum acceptable price age |

This ensures that monetary policy becomes more conservative as oracle uncertainty increases.

---

# Oracle Manipulation Protection

Several design choices reduce the risk of oracle manipulation.

### TWAP Pricing

Prevents short-term flash loan price distortions.

### Epoch-Based Updates

Controller only reacts once per epoch, limiting rapid policy changes.

### Deadband Filtering

Small price fluctuations are ignored by the controller.

### Gain Decay

Older prices reduce controller sensitivity.

Together these mechanisms create multiple layers of protection.

---

# Oracle Security Assumptions

The protocol assumes:

- liquidity pool prices reflect real market conditions
- TWAP windows sufficiently resist manipulation
- oracle updates occur regularly under normal conditions

These assumptions are standard across many DeFi protocols.

---

# Failure Scenarios

The oracle is designed to tolerate several failure modes.

| Scenario | System Behavior |
|---------|----------------|
| Temporary update failure | fallback to stored price |
| Short-term liquidity spikes | TWAP smoothing |
| stale price | controller gain decay |
| complete oracle outage | controller freeze |

These safeguards maintain system stability during unexpected events.

---

# Transparency

All oracle data is publicly visible on-chain.

Anyone can inspect:

- last known price
- price timestamp
- oracle health status

This transparency allows independent verification of oracle behavior.

---

# Relationship to Monetary Policy

The oracle provides the price signal used by the controller.

```
Oracle → price P
Controller → adjusts r
Vault System → changes supply incentives
```

Accurate price data is therefore essential for effective monetary policy.

---

# Summary

The SunPLS oracle provides the price data that powers the entire protocol.

Its design focuses on:

- manipulation resistance
- graceful degradation
- transparency
- on-chain verifiability

By combining TWAP pricing with fallback modes and gain decay, the oracle system ensures that SunPLS can continue operating safely even under adverse conditions.
