# The Monetary Policy Engine

SunPLS introduces a **deterministic on-chain monetary policy engine** implemented through the Controller contract.

Unlike traditional financial systems where monetary policy is set by committees or governance votes, SunPLS executes monetary adjustments through **transparent algorithmic rules** that respond directly to market conditions.

The Controller continuously evaluates the relationship between:

- **P** — the observed market price of SunPLS  
- **R** — the system’s internal equilibrium price  

and adjusts the system borrowing rate **r** accordingly.

---

# Core Control Equation

The controller implements a proportional feedback mechanism:

```
ε = P − R
Δr = K × (ε / R)
```

Where:

| Variable | Description |
|--------|-------------|
| P | Market price of SunPLS |
| R | Internal equilibrium price |
| ε | Price deviation |
| r | System borrowing rate |
| K | Controller gain coefficient |

This creates a **closed economic feedback loop**.

---

# Policy Response

The controller modifies borrowing conditions depending on the price deviation.

### If P > R

SunPLS is trading above equilibrium.

Controller response:

```
r increases
```

Effect:

- borrowing becomes more expensive  
- minting slows  
- supply growth decreases  
- market price falls toward equilibrium

---

### If P < R

SunPLS is trading below equilibrium.

Controller response:

```
r decreases
```

Effect:

- borrowing becomes cheaper  
- minting increases  
- supply expands  
- market price rises toward equilibrium

---

# Deadband Stabilization

Small market fluctuations should not trigger policy changes.

SunPLS therefore implements a **deadband region**.

```
|P − R| / R < Deadband → no rate change
```

This prevents the controller from reacting to normal trading noise.

---

# Rate Limiter

To prevent sudden policy shocks, the controller limits how quickly interest rates can change.

```
|Δr| ≤ δr_max
```

This ensures that monetary policy evolves smoothly across epochs rather than through abrupt adjustments.

---

# Oracle Safety

Because the controller depends on price signals, SunPLS introduces **multiple layers of oracle resilience**.

The controller operates under four oracle modes:

| Mode | Description |
|-----|-------------|
| Mode A | Fresh oracle update |
| Mode B | Fallback peek value |
| Mode C | Stored last known price |
| Mode D | System freeze if price unavailable |

These mechanisms allow the controller to **degrade gracefully rather than fail catastrophically**.

---

# Dynamic Controller Gain

When price information becomes stale, the controller reduces its aggressiveness.

```
effectiveK = K × (1 − age / MAX_P_AGE)
```

This prevents excessive policy reactions based on outdated market data.

---

# Emergency Protection

If the system detects a critical drop in vault health, the controller enters emergency mode:

```
r = MAX_RATE
```

This immediately increases borrowing costs and encourages rapid deleveraging of the system.

---

# Epoch-Based Operation

The controller executes policy adjustments once per epoch.

Typical epoch duration:

```
1 hour
```

Each epoch performs the following sequence:

1. Retrieve oracle price P  
2. Compute deviation ε  
3. Apply deadband filter  
4. Calculate Δr  
5. Apply rate limiter  
6. Update r  
7. Log telemetry  

---

# System Telemetry

The controller records several operational metrics:

| Metric | Purpose |
|------|---------|
| limiterHits | detects excessive controller pressure |
| deadbandSkips | tracks price noise |
| oracleFallbacks | monitors oracle health |
| frozenEpochs | detects oracle outages |
| emergencyEpochs | records stress events |

These metrics allow the protocol’s behavior to be monitored transparently on-chain.

---

# Why This Matters

Traditional monetary systems rely on discretionary decisions made by central banks.

SunPLS replaces discretionary policy with **deterministic control logic**.

Instead of:

```
policy committee
↓
interest rate decision
```

SunPLS operates as:

```
market price signal
↓
controller algorithm
↓
automatic policy adjustment
```

This transforms monetary policy into a **transparent and autonomous process executed by code**.

---

# Toward Autonomous Monetary Systems

The SunPLS controller represents an experimental step toward a new class of financial infrastructure:

**Autonomous Monetary Protocols (AMPs)**

where:

- policy rules are deterministic  
- enforcement is permissionless  
- economic adjustments occur automatically  
- system transparency is guaranteed on-chain

The success of such systems depends on their ability to maintain stability under real market conditions.

SunPLS serves as a live experiment exploring this possibility.
