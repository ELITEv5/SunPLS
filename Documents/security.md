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

Every SunPLS token is backed by excess collateral deposited in vaults. Minting requires a minimum 150% collateral ratio.

This ensures that even during market volatility, the system remains solvent.

---

### Deterministic Enforcement

All safety conditions are enforced by smart contract logic rather than discretionary governance.

Critical rules include:

```
vault liquidation at CR < 110%
redemption eligibility at CR ≤ 130%
rate limiter enforcement (0.05% per epoch)
oracle fallback behavior (four modes)
bounded equilibrium movement (10% per epoch)
```

---

### Permissionless Safety Mechanisms

Key enforcement actions are open to any participant.

Anyone can:

- liquidate unsafe vaults (CR < 110%)
- redeem SunPLS against distressed vaults (CR ≤ 130%)
- trigger controller epochs

This prevents reliance on trusted actors.

---

### Immutability

All contract parameters are set at deployment and cannot be changed. The vault address is latched once via `setVault()` and the latch cannot be reopened. No admin keys, no upgrade proxies, no governance.

---

### Transparency

All system variables are publicly visible on-chain, including:

- equilibrium value `R`
- system borrowing rate `r`
- oracle price `P`
- vault collateral and debt
- controller telemetry counters

This allows independent monitoring of protocol health.

---

# System Invariants

SunPLS maintains critical safety invariants across both contracts.

| ID | Invariant | Purpose |
|----|-----------|---------|
| I1 | `MIN_RATE ≤ r ≤ MAX_RATE` | prevents extreme policy changes |
| I2 | `|Δr| ≤ DELTA_R_MAX` | limits rate volatility per epoch |
| I3 | `R ≥ R_FLOOR` | protects redemption math from collapse |
| I4 | `|ΔR| ≤ R × 10%` per epoch | prevents equilibrium shocks |
| I5 | R only updates on Mode A (fresh price) | prevents R drift from stale data |
| I6 | Oracle failure cannot halt system | liveness guaranteed, epochs always advance |
| I7 | Vault failure in `updateRate()` cannot block epoch | controller liveness independent of vault |
| I8 | CR ≥ 150% required to mint or withdraw | no undercollateralized issuance |
| I9 | Liquidation only when CR < 110% | no false liquidations |
| I10 | Redemption only when CR ≤ 130% | healthy vaults immune |
| I11 | Redemption cannot make vault collateral negative | no underflow |
| I12 | `setVault()` one-time latch, irrevocable | no post-deploy admin control |
| I13 | 5-minute redemption-liquidation gap | vault owners have response window |
| I14 | Bad debt recorded in `badDebt`, never silent | transparent accounting |

---

# Oracle Security

The oracle provides the only external input into the system.

Several protections mitigate oracle risk.

### TWAP Pricing

Prices are derived from Uniswap V2 cumulative price accumulators with a minimum 60-second TWAP window. This resists flash loan manipulation — sustained price across multiple blocks is required to move the oracle.

---

### Creeping Anti-Manipulation Mechanism

Large price moves (>5%) require three confirmations within a 1% tolerance band before being accepted. The oracle then creeps `lastPrice` toward the confirmed price in 10% steps. A 40% price move takes approximately 12 minutes to fully resolve.

This prevents a single manipulated reading from immediately affecting protocol behavior.

---

### Split Timestamps

The oracle maintains separate `lastUpdateTimestamp` and `lastPriceTimestamp`. Staleness signals reflect actual price age — not just whether `update()` was recently called. During creep confirmation accumulation the update gate advances correctly while staleness is reported accurately.

---

### Oracle Fallback Modes

The controller supports four degradation modes.

| Mode | Behavior | K | R |
|-----|-----------|---|---|
| Mode A | Fresh oracle update | Full K | Updates |
| Mode B | Peek fallback price | K decayed | Frozen |
| Mode C | Stored last known price | K decayed | Frozen |
| Mode D | No usable price | 0, rate frozen | Frozen |

Epochs always advance. The system never permanently stalls.

---

### Gain Decay

When price data becomes stale, controller sensitivity decreases.

```
effectiveK = K × (MAX_P_AGE − age) / MAX_P_AGE
```

Minimum effectiveK is 1 (not zero). Beyond MAX_P_AGE (24 hours), the controller enters Mode D.

---

# Liquidation Security

Liquidations are critical for maintaining system solvency.

### Deterministic Eligibility

A vault becomes liquidatable only when:

```
CR < 110%

CR = (collateral × 1e18 × 100) / (debt × price)
```

### Dutch Auction Incentive

The liquidation bonus grows from 2% to 5% over 3 hours from when the vault first became undercollateralized. This ensures rapid enforcement while guaranteeing a minimum return even for immediate liquidations.

### Minimum Size Enforcement

Liquidations must be at least 20% of vault debt (`MIN_LIQUIDATION_BPS = 2000`). This prevents dust liquidations and ensures each transaction meaningfully reduces system risk.

### Bad Debt Transparency

If a vault is so deeply underwater that the liquidation reward exceeds remaining collateral, the deficit is recorded in `badDebt` rather than silently absorbed. This prevents hidden insolvency.

### Cooldown

A 10-minute cooldown (`LIQUIDATION_COOLDOWN = 600s`) between successive liquidations of the same vault prevents spam and front-running wars.

---

# Redemption Security

Redemptions allow SunPLS holders to exchange for PLS at the current R value. Several protections govern this mechanism.

### Vault Immunity Above 130% CR

Only vaults at or below 130% CR can be redeemed against. Vaults above this threshold are completely immune. This protects healthy vault owners from involuntary collateral reduction.

### Explicit Vault Targeting

Redeemers must specify which vault to redeem against via `redeem(sunplsAmount, targetVault)`. There is no automatic selection. This prevents surprise redemptions on vaults owners intended to keep open.

### Redemption Fee

A 0.5% fee (`REDEMPTION_FEE_BPS = 50`) is retained in the vault as collateral. This compensates vault owners and creates a small economic friction that discourages redemption spam.

### Redemption-Liquidation Gap

A vault cannot be liquidated within 5 minutes of being redeemed against. This gives vault owners time to add collateral or repay debt before liquidators can act.

### Atomic Execution

Redemptions occur in a single transaction. Partial states are not possible.

---

# Controller Safety Mechanisms

### Deadband Filter

```
ε = |P − R| / R ≤ DEADBAND (0.1%)
```

Deviations within this range produce no rate change. Prevents unnecessary policy churn from market noise.

### Rate Limiter

```
|Δr| ≤ DELTA_R_MAX (0.05% per epoch)
```

Caps policy changes to ensure gradual monetary evolution.

### Equilibrium Movement Limit

```
|ΔR| ≤ R × 10% per epoch
```

Prevents large systemic shocks from rapid R movement.

### Emergency Protection

If system health drops below 120% at the start of an epoch:

```
r = MAX_RATE (20% APR)
```

This check runs before oracle resolution and cannot be bypassed by oracle failure.

---

# Vault Latch Security

The circular deployment dependency (Controller needs Vault, Vault needs Controller) is resolved via a one-time `setVault()` latch on both Token and Controller.

After latching:

- `vaultSet = true` permanently
- all subsequent calls to `setVault()` revert
- no address can be substituted by any actor including the original deployer

This is equivalent in security to an immutable constructor parameter while allowing the correct deployment sequence.

---

# Liveness Guarantees

| Scenario | System Behavior |
|---------|----------------|
| Oracle update fails | Mode B peek fallback, K decayed |
| Oracle fully unavailable | Mode D, rate frozen, epoch still advances |
| Vault `updateRate()` reverts | Controller catches error, epoch completes |
| Liquidation race condition | First valid transaction wins, cooldown prevents spam |
| Extreme market volatility | Dutch auction ensures timely liquidations |
| System health < 120% | Emergency MAX_RATE forced, cannot be bypassed |

---

# Attack Surface

Potential attack vectors and mitigations:

| Vector | Mitigation |
|---|---|
| Oracle price manipulation | TWAP (60s window) + creeping (3 confirmations + 10% step) |
| Flash loan distortion | TWAP requires sustained price across blocks |
| Redemption targeting healthy vaults | 130% CR immunity threshold |
| Liquidation → redemption griefing | 5-minute redemption-liquidation gap |
| Vault latch substitution | One-time irrevocable latch |
| Admin key compromise | No admin keys exist post-latch |
| MEV on liquidations | Permissionless, competitive, cooldown limits spam |
| Dust liquidations | 20% minimum liquidation size |

---

# Known Limitations

### Collateral Volatility

PLS price volatility directly affects vault safety. Extreme price drops may trigger liquidation cascades. The 150% minimum CR provides a buffer but cannot eliminate this risk.

### Liquidity Dependence

Oracle price accuracy depends on PulseX pool depth. Low liquidity may increase price volatility and oracle manipulation risk.

### Economic Feedback Lag

The controller reacts in discrete hourly epochs. Rapid market movements may temporarily widen price deviations before the next epoch closes them.

### Single Collateral Asset

SunPLS accepts only PLS as collateral. There is no diversification across collateral types.

---

# Risk Disclosure

SunPLS is an experimental protocol.

Users should understand that:

- smart contracts may contain unknown vulnerabilities
- market conditions may cause unexpected outcomes
- the system has no central administrator and cannot be paused or patched post-deployment

Participation is entirely voluntary.

---

# Responsible Disclosure

If a vulnerability is discovered, researchers are encouraged to report it privately before public disclosure. Responsible reporting helps protect users and maintain protocol integrity.

---

# Security Summary

SunPLS security is based on several core pillars:

- overcollateralized vaults (150% minimum CR)
- deterministic liquidation rules (CR < 110%, Dutch auction)
- redemption protection for healthy vaults (CR > 130% immune)
- algorithmic monetary policy (feedback controller, no governance)
- oracle resilience (TWAP, creeping, four fallback modes)
- full immutability post-latch (no admin keys, no upgrades)

Together these components create a system designed to remain solvent, transparent, and autonomous.

---

# References

ProjectUSD Controller Specification  
ProjectUSD Stability Model Research  
Decentralized Finance Security Practices
