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
Δr = K × ε
```

Where:

```
ε = |P − R| / R  (normalized deviation)
```

Typical interpretation:

```
1% price deviation → ~0.1% rate adjustment per epoch
```

This produces a moderate stabilization response. K is immutable after deployment.

---

## ALPHA — Equilibrium Damping

```
ALPHA = 5e15
```

Meaning:

Rate at which the equilibrium value `R` moves toward the observed market price each epoch.

Equation:

```
ΔR = ALPHA × (P − R)
```

Capped at MAX_R_MOVE_BPS (10%) per epoch regardless of ALPHA.

This prevents sudden shifts in the equilibrium value and smooths long-term adjustments. ALPHA is immutable after deployment.

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
ε = |P − R| / R ≤ DEADBAND
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

Maximum rate change allowed per epoch regardless of deviation size.

Limiter rule:

```
|Δr| ≤ DELTA_R_MAX
```

This prevents abrupt monetary policy changes that could destabilize borrowing incentives. When the limiter fires, `limiterHits` is incremented.

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
-5% APR
```

Meaning:

The lowest possible borrowing rate.

Negative rates reduce vault debt over time, incentivizing supply expansion when SunPLS trades persistently below equilibrium. This is the last autonomous recovery tool available when redemption liquidity is exhausted — the controller can push rates negative to encourage new supply without requiring external intervention.

---

## MAX_RATE

```
MAX_RATE = 20e16
```

Equivalent to:

```
20% APR
```

Meaning:

The highest possible borrowing rate.

High rates discourage borrowing and reduce supply expansion. MAX_RATE is also the forced rate during emergency epochs when system health drops below EMERGENCY_HEALTH_THRESHOLD.

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
1. Emergency health check
2. Oracle price resolution (Modes A → B → C → D)
3. Deviation calculation
4. Rate adjustment
5. R update (Mode A only)
6. Rate push to vault
```

Epoch execution is permissionless — anyone can call `triggerEpoch()` once the duration has elapsed. Epoch-based updates prevent excessive policy reactions.

---

# Equilibrium Value Constraints

The equilibrium value `R` defines the internal system exchange rate between SunPLS and PLS, expressed in WPLS per SunPLS.

---

## R_FLOOR

```
R_FLOOR = 1e18
```

Meaning:

Minimum value R is permitted to reach.

This prevents R from collapsing to zero, which would break redemption arithmetic. R is enforced at or above R_FLOOR after every epoch.

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

Maximum allowed movement of `R` per epoch regardless of ALPHA or deviation size.

Rule:

```
|ΔR| ≤ R × 10%
```

This prevents large equilibrium shifts that could destabilize the system. R only moves during Mode A epochs (fresh oracle price required).

---

# Oracle Safety Parameters

These parameters define how the protocol behaves when oracle price data becomes stale.

---

## MAX_P_AGE

```
MAX_P_AGE = 24 hours
```

Meaning:

Maximum acceptable age of a stored price before K decays to its minimum.

K decay formula:

```
effectiveK = K × (MAX_P_AGE − age) / MAX_P_AGE
```

As price age approaches MAX_P_AGE, effectiveK approaches 1 (minimum, not zero).
Beyond MAX_P_AGE with no oracle recovery, the controller enters Mode D and freezes rate updates while still advancing the epoch.

---

# Emergency Safety Parameter

---

## EMERGENCY_HEALTH_THRESHOLD

```
EMERGENCY_HEALTH_THRESHOLD = 120
```

Meaning:

System collateralization threshold (120% CR) below which emergency measures activate.

If vault system health falls below this level at the start of an epoch:

```
r = MAX_RATE (20% APR)
```

This check runs before oracle resolution and cannot be bypassed by oracle failure. The epoch still advances normally after the emergency rate is pushed.

---

# Vault Parameters

These parameters are set in the Vault contract and govern CDP behavior.

---

## COLLATERAL_RATIO

```
COLLATERAL_RATIO = 150
```

Minimum collateral ratio (150%) required to mint SunPLS or withdraw collateral.

---

## LIQUIDATION_RATIO

```
LIQUIDATION_RATIO = 110
```

Collateral ratio (110%) below which a vault becomes liquidatable via Dutch auction.

---

## REDEMPTION_RATIO

```
REDEMPTION_RATIO = 130
```

Collateral ratio threshold (130%) at or below which a vault can be redeemed against. Vaults above 130% CR are completely immune to redemption.

---

## AUTOMINT_RATIO

```
AUTOMINT_RATIO = 155
```

Collateral ratio used by `depositAndAutoMintPLS()` — mints SunPLS at 155% CR in a single transaction.

---

## REDEMPTION_FEE_BPS

```
REDEMPTION_FEE_BPS = 50
```

Equivalent to 0.5%. Fee retained by the vault owner as collateral during a redemption. Does not leave the vault.

---

## REDEMPTION_LIQUIDATION_GAP

```
REDEMPTION_LIQUIDATION_GAP = 300 seconds
```

A vault cannot be liquidated within 5 minutes of being redeemed against. Gives vault owners time to respond.

---

## LIQUIDATION_COOLDOWN

```
LIQUIDATION_COOLDOWN = 600 seconds
```

Minimum time between successive liquidations of the same vault.

---

## MIN_LIQUIDATION_BPS

```
MIN_LIQUIDATION_BPS = 2000
```

Minimum liquidation size is 20% of the vault's outstanding debt.

---

## MIN_BONUS_BPS / MAX_BONUS_BPS

```
MIN_BONUS_BPS = 200   (2%)
MAX_BONUS_BPS = 500   (5%)
AUCTION_TIME  = 3 hours
```

Dutch auction liquidation bonus grows from 2% to 5% over 3 hours from when the vault first became undercollateralized.

---

## WITHDRAW_COOLDOWN

```
WITHDRAW_COOLDOWN = 300 seconds
```

5-minute cooldown after any deposit before collateral can be withdrawn.

---

## MIN_SYSTEM_HEALTH

```
MIN_SYSTEM_HEALTH = 130
```

System-wide collateralization floor below which new minting is blocked.

---

## EMERGENCY_UNLOCK_TIME

```
EMERGENCY_UNLOCK_TIME = 30 days
```

After 30 days of inactivity with zero debt, a vault owner can withdraw collateral regardless of other conditions.

---

# Telemetry Counters

The protocol tracks several operational statistics on-chain.

---

## limiterHits

Number of epochs where the rate limiter was triggered.

High values indicate the controller is consistently hitting DELTA_R_MAX — strong sustained deviation pressure.

---

## deadbandSkips

Number of epochs where price deviation fell within the deadband.

High values indicate stable market conditions with P near R.

---

## oracleFallbacks

Number of epochs where oracle fallback modes (B or C) were used.

This metric measures oracle reliability over time.

---

## frozenEpochs

Number of epochs where no valid price was available (Mode D).

Rate updates are frozen but epochs still advance.

---

## emergencyEpochs

Number of times the controller activated emergency rate protection.

Each event forced r = MAX_RATE due to system health below 120%.

---

# Parameter Philosophy

SunPLS deliberately keeps the parameter set small and immutable.

Goals:

- easier economic analysis
- zero governance risk post-deploy
- lower implementation complexity
- predictable deterministic behavior

K and ALPHA are set at construction and cannot be changed. All vault ratios are compile-time constants. The system behaves identically from day one to year ten.

---

# Parameter Transparency

All Controller parameters are visible on-chain:

```
getParameters()
```

All current system state is visible on-chain:

```
getCurrentState()
```

This transparency ensures the protocol's economic rules are publicly verifiable at any time.

---

# Parameter Summary

| Parameter | Value | Purpose |
|-----------|-------|---------|
| K | 1e15 | Controller sensitivity |
| ALPHA | 5e15 | Equilibrium damping |
| DEADBAND | 1e15 | Noise filter (0.1%) |
| DELTA_R_MAX | 5e14 | Rate limiter (0.05%/epoch) |
| MIN_RATE | -5e16 | Minimum borrowing rate (−5% APR) |
| MAX_RATE | 20e16 | Maximum borrowing rate (20% APR) |
| EPOCH_DURATION | 3600s | Policy update interval (1 hour) |
| R_FLOOR | 1e18 | Minimum bound on R |
| MAX_R_MOVE_BPS | 1000 | Max R adjustment (10%/epoch) |
| MAX_P_AGE | 86400s | Oracle freshness threshold (24h) |
| EMERGENCY_HEALTH_THRESHOLD | 120 | System stress protection |
| COLLATERAL_RATIO | 150 | Minimum vault CR to mint/withdraw |
| LIQUIDATION_RATIO | 110 | Vault CR below which liquidation opens |
| REDEMPTION_RATIO | 130 | Vault CR at/below which redemption opens |
| AUTOMINT_RATIO | 155 | Auto-mint target CR |
| REDEMPTION_FEE_BPS | 50 | Redemption fee (0.5%) |
| REDEMPTION_LIQUIDATION_GAP | 300s | Post-redemption liquidation freeze |
| LIQUIDATION_COOLDOWN | 600s | Min time between liquidations |
| MIN_LIQUIDATION_BPS | 2000 | Min liquidation size (20% of debt) |
| MIN_BONUS_BPS | 200 | Starting liquidation bonus (2%) |
| MAX_BONUS_BPS | 500 | Maximum liquidation bonus (5%) |
| AUCTION_TIME | 10800s | Dutch auction duration (3 hours) |
| WITHDRAW_COOLDOWN | 300s | Post-deposit withdrawal freeze |
| MIN_SYSTEM_HEALTH | 130 | System-wide minting floor |
| EMERGENCY_UNLOCK_TIME | 2592000s | Emergency collateral release (30 days) |

---

# References

Conceptual inspiration:

ProjectUSD Whitepaper  
ProjectUSD Controller Specification  
Feedback Control Systems in Monetary Policy
