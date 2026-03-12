# SunPLS Redemptions

Redemptions allow any SunPLS holder to exchange SunPLS directly for PLS at the current value of R.

This mechanism creates arbitrage pressure that converges market price toward R and plays a critical role in maintaining long-term stability.

Unlike market trades on decentralized exchanges, redemptions occur directly through the protocol using the internal equilibrium value `R`.

```
PLS received = SunPLS burned × R
```

If the market price of SunPLS falls below R, arbitrage incentives encourage users to redeem SunPLS and restore price equilibrium.

---

# Purpose of Redemptions

Redemptions serve several important functions in the SunPLS protocol.

They:

- create arbitrage incentives that pressure market price toward R
- reduce prolonged price deviations below equilibrium
- remove excess supply from circulation
- maintain confidence in the system

Without redemptions, a collateralized stable asset could trade below its intrinsic value for extended periods.

Redemptions create continuous arbitrage pressure that works to correct such deviations.

---

# Redemption Price

The redemption price is determined by the **equilibrium value `R`** maintained by the Controller.

R is expressed in **WPLS per SunPLS**.

Example:

```
R = 97,500 PLS per SunPLS
```

Then burning 0.055 SunPLS yields:

```
0.055 × 97,500 = 5,362.5 PLS received (before fee)
```

This value reflects the current equilibrium relationship between SunPLS and its collateral.

---

# Redemption Flow

The redemption process follows a deterministic sequence.

```
User holds SunPLS
↓
User calls redeem(sunplsAmount, targetVault)
↓
Protocol verifies target vault CR ≤ 130%
↓
SunPLS burned from redeemer
↓
Vault debt reduced
↓
Vault collateral reduced (net of fee)
↓
User receives PLS
```

The redeemed SunPLS is burned, canceling outstanding vault debt and permanently reducing supply.

---

# Vault Selection

In SunPLS, the redeemer **explicitly specifies the target vault** when calling `redeem()`.

There is no automatic vault selection by the protocol.

The target vault must meet one condition:

- collateral ratio **at or below 130%**

Vaults above 130% CR are completely immune to redemption and cannot be targeted under any circumstances.

This design protects healthy vault owners from involuntary exits while ensuring redemption pressure falls only on genuinely distressed positions.

Redeemers can use the on-chain vault enumeration functions (`getVaultCount()`, `getVaultOwner(index)`) to identify eligible vaults without relying on event log scanning.

---

# Vault CR Zones

| CR Range | Redemption Eligible |
|---|---|
| Above 150% | No — healthy, fully immune |
| 130%–150% | No — distressed but immune |
| At or below 130% | Yes — eligible target |
| Below 110% | Yes — also liquidatable |

---

# Redemption Example

```
User redeems: 0.055 SunPLS
Equilibrium value R = 97,500 PLS per SunPLS
Redemption fee: 0.5%
```

Gross PLS out:

```
0.055 × 97,500 = 5,362.5 PLS
```

Fee (stays with vault owner as collateral):

```
5,362.5 × 0.005 = 26.8 PLS
```

User receives:

```
5,362.5 − 26.8 = 5,335.7 PLS
```

Vault debt reduced by 0.055 SunPLS.
Vault collateral reduced by 5,335.7 PLS (fee remains as vault collateral).

---

# Arbitrage Convergence Mechanism

Redemptions create a natural arbitrage opportunity when SunPLS trades below equilibrium.

Example:

```
DEX price = 90,000 PLS per SunPLS
R         = 97,500 PLS per SunPLS
```

Arbitrage strategy:

```
Buy SunPLS at 90,000 PLS
Redeem at R = 97,500 PLS
Profit ≈ 7,500 PLS per SunPLS (before fee)
```

This process continues until market price converges toward R. R itself is a derived system state, not a guaranteed bound — it moves as the controller responds to sustained deviation.

---

# Market Stabilization

Redemptions stabilize the system through two simultaneous effects.

```
SunPLS supply decreases
↓
market scarcity increases
↓
price rises toward equilibrium
```

At the same time:

```
vault debt decreases
↓
system leverage decreases
↓
system health improves
```

These dynamics improve overall system safety.

---

# Redemption Fee

SunPLS charges a **0.5% redemption fee**.

The fee does not leave the vault — it remains as the vault owner's collateral. This is compensation to the vault owner for the involuntary exit.

Example:

```
Gross PLS out = 5,362.5 PLS
Fee (0.5%)    = 26.8 PLS  ← stays in vault as owner's collateral
User receives = 5,335.7 PLS
```

The fee is small enough to preserve strong arbitrage incentives while providing meaningful compensation to affected vault owners.

---

# Vault Owner Protections

Vault owners have several protections against redemption:

**Immunity above 130% CR** — vaults above 130% CR cannot be targeted. Maintaining a healthy CR is the primary defense.

**0.5% fee retained** — the fee stays as the vault owner's collateral, partially offsetting the collateral reduction.

**5-minute liquidation gap** — after being redeemed against, a vault cannot be liquidated for 5 minutes. This gives the vault owner time to add collateral or repay debt before a liquidator can act.

**Explicit targeting** — redemptions require the redeemer to specify the target vault. There is no automatic selection that can surprise a vault owner.

---

# System Effects

Redemptions affect several key system metrics.

| Metric | Impact |
|------|------|
| Total SunPLS Supply | decreases |
| Vault Debt | decreases |
| Vault Collateral | decreases (net of fee) |
| System Health | typically improves |
| Market Price | pushed toward R |

These effects contribute to long-term system stability.

---

# Interaction With the Controller

The controller adjusts borrowing rates based on price deviations.

Redemptions complement this mechanism.

Controller effect:

```
adjust borrowing incentives over time
```

Redemption effect:

```
directly remove excess supply immediately
```

Together they create a **dual stabilization system**.

---

# Relationship With Liquidations

Liquidations and redemptions serve different roles.

| Mechanism | Trigger | Purpose |
|----------|---------|---------|
| Liquidations | CR below 110% | remove insolvent vaults |
| Redemptions | CR at or below 130% | correct market price deviations |

Liquidations protect solvency.

Redemptions protect price stability.

Both mechanisms work together to maintain system integrity.

---

# Example Market Scenario

Consider the following situation:

```
SunPLS market price = 90,000 PLS per SunPLS
Equilibrium value R = 97,500 PLS per SunPLS
```

Arbitrage occurs:

```
Traders buy SunPLS at 90,000 PLS
↓
Redeem against distressed vaults (CR ≤ 130%) at R
↓
SunPLS supply shrinks
↓
Price returns toward R
```

This mechanism stabilizes the protocol without centralized intervention.

---

# Summary

Redemptions are the **arbitrage convergence mechanism** of the SunPLS protocol.

They ensure that:

- arbitrage incentives pressure market price toward R
- supply contracts when price falls below R
- only genuinely distressed vaults (CR ≤ 130%) absorb redemption pressure
- healthy vault owners above 130% CR are completely protected

Combined with vault liquidations and controller-based monetary policy, redemptions form a key component of SunPLS' autonomous stabilization system.
