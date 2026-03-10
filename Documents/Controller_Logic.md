# SunPLS Controller vs ProjectUSD Controller  
### Architectural Comparison

This document compares the **SunPLS Controller (production implementation)** with the **ProjectUSD Controller SPEC v1 (design specification)**.

Both controllers share the same economic foundation: a **feedback control loop** that adjusts system rates based on the deviation between market price **P** and internal equilibrium value **R**.

However, the SunPLS controller introduces additional safety mechanisms and operational hardening that extend the original design into a more resilient production system.

---

# 1. Shared Core Principle

Both controllers implement a **proportional feedback controller**:

```
ε = P − R
Δr = K × (ε / R)
```

Where:

| Variable | Meaning |
|--------|--------|
| P | Market price |
| R | System equilibrium value |
| ε | Deviation between market and equilibrium |
| r | System interest rate |
| K | Proportional gain |

Controller behavior:

- **P > R → r increases → borrowing slows → supply tightens**
- **P < R → r decreases → borrowing accelerates → supply expands**

Goal:

```
P → R over time
```

This creates **algorithmic monetary policy without governance intervention**.

---

# 2. Key Architectural Differences

## 2.1 Oracle Resilience

### ProjectUSD Controller

Oracle failure handling:

```
If Oracle STALE → Δr = 0
```

This freezes policy updates.

---

### SunPLS Controller

SunPLS introduces a **multi-stage oracle degradation model**:

| Mode | Description |
|-----|-------------|
| Mode A | Fresh oracle update |
| Mode B | Peek fallback |
| Mode C | Stored price fallback |
| Mode D | Freeze system |

This ensures:

- controller continues functioning during oracle issues
- graceful degradation instead of immediate freeze
- system liveness during temporary failures

**Advantage: SunPLS**

---

# 3. Dynamic Gain Adjustment (K Decay)

SunPLS reduces controller aggressiveness when price data becomes stale.

```
effectiveK = K × (1 - age / MAX_P_AGE)
```

This prevents:

- overreaction to stale prices
- instability during oracle delays

ProjectUSD SPEC does not include dynamic gain reduction.

**Advantage: SunPLS**

---

# 4. Emergency System Protection

SunPLS includes a **vault health emergency mode**.

If system collateralization drops below threshold:

```
r = MAX_RATE
```

This forces rapid deleveraging across vaults.

The ProjectUSD controller does not define a similar automatic emergency mechanism.

**Advantage: SunPLS**

---

# 5. Controlled R Adjustment

SunPLS constrains how quickly the equilibrium value can move:

| Mechanism | SunPLS | ProjectUSD |
|-----------|--------|-----------|
| R update requires fresh oracle | ✓ | not specified |
| Maximum R change per epoch | ✓ | not defined |
| R minimum movement bound enforced | ✓ | not specified |

These protections prevent rapid shifts that could destabilize the system.

**Advantage: SunPLS**

---

# 6. Autonomous Operation

ProjectUSD SPEC assumes integration with several system modules:

```
Controller
VaultEngine
StabilityPool
SurplusBuffer
```

SunPLS intentionally simplifies architecture:

```
Oracle
Controller
Vault
Liquidations
Redemptions
```

Benefits:

- fewer dependencies
- reduced attack surface
- simpler system invariants

**Advantage: SunPLS**

---

# 7. Controller Telemetry

SunPLS records operational telemetry on-chain:

| Metric | Purpose |
|------|---------|
| limiterHits | Detect rate limiter saturation |
| deadbandSkips | Monitor price noise |
| oracleFallbacks | Detect oracle degradation |
| frozenEpochs | Identify oracle outages |
| emergencyEpochs | Track systemic stress events |

The ProjectUSD SPEC defines telemetry conceptually but does not implement tracking directly.

**Advantage: SunPLS**

---

# 8. Safety Invariants Enforcement

SunPLS enforces strict system boundaries:

```
|Δr| ≤ DELTA_R_MAX
MIN_RATE ≤ r ≤ MAX_RATE
R ≥ R_FLOOR
```

These constraints ensure:

- bounded policy changes
- no runaway interest rates
- stable equilibrium reference

The SPEC defines invariants but leaves implementation details open.

**Advantage: SunPLS**

---

# 9. Control System Engineering

ProjectUSD describes a **basic proportional controller**.

SunPLS implements a **hardened control system** with:

- deadband filtering
- rate limiting
- oracle degradation handling
- emergency overrides
- bounded state transitions
- telemetry monitoring

This structure resembles **industrial control systems** designed for continuous operation.

---

# 10. Summary

| Feature | ProjectUSD Controller | SunPLS Controller |
|-------|----------------------|------------------|
| Feedback stabilization | ✓ | ✓ |
| Deadband | ✓ | ✓ |
| Rate limiter | ✓ | ✓ |
| Oracle degradation modes | ✗ | ✓ |
| Dynamic gain decay | ✗ | ✓ |
| Emergency system protection | ✗ | ✓ |
| Controlled R movement | partial | ✓ |
| System telemetry | conceptual | ✓ |
| Simplified architecture | ✗ | ✓ |

---

# Conclusion

The SunPLS Controller can be seen as a **production-grade evolution of the ProjectUSD controller concept**.

While the ProjectUSD SPEC defines the theoretical framework for feedback-based stabilization, SunPLS extends the design with:

- stronger fault tolerance
- additional safety constraints
- improved oracle handling
- simplified system dependencies
- real-time telemetry

These enhancements make the SunPLS controller **more resilient and better suited for autonomous on-chain monetary policy**.

---

# Final Note

Both designs share the same core philosophy:

> Stability through deterministic feedback rather than governance.

SunPLS builds upon that philosophy by introducing the additional engineering safeguards required for real-world deployment.
