# SunPLS Security Model

This document describes the security assumptions, protections, and potential risks of the SunPLS protocol.

SunPLS is designed as a **minimal autonomous financial system**.  
Security is achieved through deterministic rules, overcollateralization, and permissionless enforcement rather than administrative control.

The protocol's safety relies on a combination of:

- economic incentives  
- strict invariants  
- bounded system parameters  
- oracle resilience  
- transparent on-chain telemetry  

---

# Security Philosophy

SunPLS follows several guiding security principles.

### Overcollateralization

Every SunPLS token is backed by excess collateral deposited in vaults.

This ensures that even during market volatility, the system remains solvent.

---

### Deterministic Enforcement

All safety conditions are enforced by smart contract logic rather than discretionary governance.

Critical rules include:

```
vault liquidation thresholds
rate limiter enforcement
oracle fallback behavior
bounded equilibrium movement
```

---

### Permissionless Safety Mechanisms

Key enforcement actions are open to any participant.

Anyone can:

- liquidate unsafe vaults  
- redeem SunPLS for collateral  
- trigger controller epochs  

This prevents reliance on trusted actors.

---

### Transparency

All system variables are publicly visible on-chain, including:

- equilibrium value `R`
- system borrowing rate `r`
- oracle price `P`
- vault collateral and debt

This allows independent monitoring of protocol health.

---

# System Invariants

SunPLS maintains several critical safety invariants.

| ID | Invariant | Purpose |
|----|-----------|---------|
| I1 | `MIN_RATE ≤ r ≤ MAX_RATE` | prevents extreme policy changes |
| I2 | `|Δr| ≤ DELTA_R_MAX` | limits rate volatility |
| I3 | `R ≥ R_FLOOR` | protects redemption math |
| I4 | `|ΔR| ≤ MAX_R_MOVE_BPS` | prevents equilibrium shocks |
| I5 | liquidations remove unsafe vaults | maintains collateral backing |
| I6 | oracle failure cannot halt system | ensures liveness |

These invariants guarantee predictable protocol behavior.

---

# Oracle Security

The oracle provides the only external input into the system.

Several protections mitigate oracle risk.

### TWAP Pricing

Prices are derived from time-weighted averages rather than instantaneous trades.

This reduces susceptibility to flash-loan manipulation.

---

### Oracle Fallback Modes

The controller supports multiple degradation modes.

| Mode | Behavior |
|-----|-----------|
| Mode A | fresh oracle update |
| Mode B | fallback peek price |
| Mode C | stored last known price |
| Mode D | freeze controller updates |

These modes ensure the system continues operating safely during oracle disruptions.

---

### Gain Decay

When price data becomes stale, controller sensitivity decreases.

```
effectiveK = K × (1 − age / MAX_P_AGE)
```

This reduces policy reactions to outdated information.

---

# Liquidation Security

Liquidations are critical for maintaining system solvency.

Safety mechanisms include:

### Deterministic Eligibility

A vault becomes liquidatable only when:

```
CR < LiquidationThreshold
```

Where:

```
CR = collateral_value / debt
```

---

### Atomic Execution

Liquidations occur in a single transaction.

This prevents partial states or inconsistent system accounting.

---

### Economic Incentives

Liquidators receive a reward for repaying unsafe debt.

This ensures liquidations occur quickly even during volatile market conditions.

---

# Redemption Security

Redemptions create arbitrage pressure that converges market price toward R.

Security protections include:

- deterministic vault selection
- atomic execution
- bounded redemption fees
- predictable collateral transfers

These mechanisms prevent manipulation or abuse.

---

# Controller Safety Mechanisms

The controller includes several protections to prevent unstable monetary policy behavior.

### Deadband Filter

Small price deviations are ignored.

```
|P − R| / R ≤ DEADBAND
```

This prevents unnecessary rate adjustments caused by market noise.

---

### Rate Limiter

The controller caps rate changes.

```
|Δr| ≤ DELTA_R_MAX
```

This ensures gradual policy evolution.

---

### Equilibrium Movement Limit

The equilibrium value cannot shift too quickly.

```
|ΔR| ≤ MAX_R_MOVE_BPS
```

This prevents large systemic shocks.

---

# Emergency Protection

If system health falls below a defined threshold:

```
r = MAX_RATE
```

This increases borrowing costs and encourages rapid deleveraging.

---

# Liveness Guarantees

The protocol is designed to remain operational even during adverse conditions.

Examples:

| Scenario | System Behavior |
|---------|----------------|
| oracle update fails | fallback price used |
| oracle unavailable | controller freezes rate |
| vault liquidation race | first valid transaction succeeds |
| extreme market volatility | liquidations remove unsafe debt |

These mechanisms prevent system shutdowns.

---

# Attack Surface

Potential attack vectors include:

- oracle price manipulation
- flash loan market distortions
- liquidation competition
- MEV extraction
- vault griefing

The protocol mitigates these risks through deterministic rules and economic incentives.

---

# MEV Considerations

Certain operations may attract MEV competition.

Examples include:

- liquidations
- redemptions
- oracle updates

Because these actions are permissionless, competition between participants ensures rapid system enforcement.

---

# Known Limitations

SunPLS does not eliminate all risks.

Important considerations include:

### Collateral Volatility

PLS price volatility directly affects vault safety.

Extreme price drops may trigger liquidation cascades.

---

### Liquidity Dependence

Oracle price accuracy depends on liquidity pool depth.

Low liquidity may increase price volatility.

---

### Economic Feedback Lag

The controller reacts in discrete epochs.

Rapid market movements may temporarily widen price deviations.

---

# Risk Disclosure

SunPLS is an experimental protocol.

Users should understand that:

- smart contracts may contain unknown vulnerabilities  
- market conditions may cause unexpected outcomes  
- the system has no central administrator  

Participation is entirely voluntary.

---

# Responsible Disclosure

If a vulnerability is discovered, researchers are encouraged to report it privately before public disclosure.

Responsible reporting helps protect users and maintain protocol integrity.

---

# Security Summary

SunPLS security is based on several core pillars:

- overcollateralized vaults  
- deterministic liquidation rules  
- redemption arbitrage convergence  
- algorithmic monetary policy  
- oracle resilience mechanisms  

Together these components create a system designed to remain solvent, transparent, and autonomous.

---

# References

ProjectUSD Controller Specification  
ProjectUSD Stability Model Research  
Decentralized Finance Security Practices
