# SunPLS Controller vs ProjectUSD Controller  
### Architectural Comparison

This document compares the **SunPLS Controller (production implementation)** with the **ProjectUSD Controller SPEC v1 (design specification)**.

Both controllers share the same economic foundation: a **feedback control loop** that adjusts system rates based on the deviation between market price **P** and internal equilibrium value **R**.

However, the SunPLS controller introduces additional safety mechanisms and operational hardening that extend the original design into a more resilient production system.

---

# 1. Shared Core Principle

Both controllers implement a **proportional feedback controller**:

```
ε = |P − R| / R
Δr = K × ε
```

Where:

| Variable | Meaning |
|--------|--------|
| P | Market price (WPLS per SunPLS) |
| R | System equilibrium value (WPLS per SunPLS) |
| ε | Normalized deviation between market and equilibrium |
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
| Mode A | Fresh oracle update — full K, R updates |
| Mode B | Peek fallback — K decayed by price age, R frozen |
| Mode C | Stored price buffer — K decayed further, R frozen |
| Mode D | No usable price — rate frozen, epoch still advances |

This ensures:

- controller continues functioning during oracle issues
- graceful degradation instead of immediate freeze
- system liveness during temporary failures
- epoch never permanently stalls regardless of oracle state

**Advantage: SunPLS**

---

# 3. Dynamic Gain Adjustment (K Decay)

SunPLS reduces controller aggressiveness when price data becomes stale.

```
effectiveK = K × (MAX_P_AGE − age) / MAX_P_AGE
```

This prevents:

- overreaction to stale prices
- instability during oracle delays

The decay is linear and reaches a minimum of 1 (not zero) so the formula never divides by zero downstream. K-decay applies in Modes B and C. Mode A always uses full K.

ProjectUSD SPEC does not include dynamic gain reduction.

**Advantage: SunPLS**

---

# 4. Emergency System Protection

SunPLS includes a **vault health emergency mode**.

If system collateralization drops below threshold (120%):

```
r = MAX_RATE (20% APR)
```

This forces rapid deleveraging across vaults. The emergency check runs at the start of every epoch before any oracle resolution, so it cannot be bypassed by oracle failure.

The ProjectUSD controller does not define a similar automatic emergency mechanism.

**Advantage: SunPLS**

---

# 5. Controlled R Adjustment

SunPLS constrains how quickly the equilibrium value can move:

| Mechanism | SunPLS | ProjectUSD |
|-----------|--------|-----------|
| R update requires fresh oracle (Mode A only) | ✓ | not specified |
| Maximum R change per epoch (10%) | ✓ | not defined |
| R minimum floor enforced (R_FLOOR) | ✓ | not specified |
| R damping via ALPHA parameter | ✓ | partial |

These protections prevent rapid shifts that could destabilize the system.

**Advantage: SunPLS**

---

# 6. Circular Deployment — Vault Latch

SunPLS resolves the Controller ↔ Vault circular deployment dependency via a **one-time vault latch**.

The Controller is deployed without a vault address. After the Vault is deployed, the deployer calls `setVault(vault)` once. This permanently latches the vault address and removes all deployer authority. `triggerEpoch()` requires the latch to be closed before executing.

This eliminates the need for nonce prediction or CREATE2 while preserving full immutability post-latch.

The ProjectUSD SPEC does not define a deployment sequence for this dependency.

**Advantage: SunPLS**

---

# 7. Autonomous Operation

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
Liquidations (built into Vault)
Redemptions (built into Vault)
```

Benefits:

- fewer dependencies
- reduced attack surface
- simpler system invariants
- no stability pool or surplus buffer required

**Advantage: SunPLS**

---

# 8. Controller Telemetry

SunPLS records operational telemetry on-chain:

| Metric | Purpose |
|------|---------|
| limiterHits | Detect rate limiter saturation |
| deadbandSkips | Monitor price noise |
| oracleFallbacks | Detect oracle degradation |
| frozenEpochs | Identify complete oracle outages (Mode D) |
| emergencyEpochs | Track systemic stress events |

All telemetry is readable via `getCurrentState()`. The ProjectUSD SPEC defines telemetry conceptually but does not implement tracking directly.

**Advantage: SunPLS**

---

# 9. Safety Invariants Enforcement

SunPLS enforces strict system boundaries:

```
|Δr| ≤ DELTA_R_MAX  (0.05% per epoch)
MIN_RATE ≤ r ≤ MAX_RATE  (−5% to +20% APR)
R ≥ R_FLOOR  (prevents division by zero)
ε ≤ DEADBAND → no rate change  (0.1% noise filter)
```

These constraints ensure:

- bounded policy changes per epoch
- no runaway interest rates
- stable equilibrium reference
- small deviations ignored rather than amplified

The SPEC defines invariants but leaves implementation details open.

**Advantage: SunPLS**

---

# 10. Control System Engineering

ProjectUSD describes a **basic proportional controller**.

SunPLS implements a **hardened control system** with:

- deadband filtering (ignore noise below 0.1%)
- rate limiting (max 0.05% change per epoch)
- oracle degradation handling (four modes)
- emergency overrides (system health below 120%)
- bounded state transitions (R capped at 10% move per epoch)
- telemetry monitoring (five on-chain counters)
- vault latch (circular deployment resolved without nonce tricks)

This structure resembles **industrial control systems** designed for continuous autonomous operation.

---

# 11. Summary

| Feature | ProjectUSD Controller | SunPLS Controller |
|-------|----------------------|------------------|
| Feedback stabilization | ✓ | ✓ |
| Deadband | ✓ | ✓ |
| Rate limiter | ✓ | ✓ |
| Oracle degradation modes (A/B/C/D) | ✗ | ✓ |
| Dynamic gain decay (K decay) | ✗ | ✓ |
| Emergency system protection | ✗ | ✓ |
| Controlled R movement (capped + ALPHA damping) | partial | ✓ |
| System telemetry (on-chain counters) | conceptual | ✓ |
| Simplified architecture (no stability pool) | ✗ | ✓ |
| Circular deployment latch | not defined | ✓ |

---

# Conclusion

The SunPLS Controller can be seen as a **production-grade evolution of the ProjectUSD controller concept**.

While the ProjectUSD SPEC defines the theoretical framework for feedback-based stabilization, SunPLS extends the design with:

- stronger fault tolerance across four oracle degradation modes
- additional safety constraints with explicit numerical bounds
- improved oracle handling with K-decay during degraded operation
- simplified system dependencies eliminating stability pool and surplus buffer
- real-time on-chain telemetry
- clean circular deployment resolution via one-time vault latch

These enhancements make the SunPLS controller **more resilient and better suited for autonomous on-chain monetary policy**.

---

# Final Note

Both designs share the same core philosophy:

> Stability through deterministic feedback rather than governance.

SunPLS builds upon that philosophy by introducing the additional engineering safeguards required for real-world deployment.
