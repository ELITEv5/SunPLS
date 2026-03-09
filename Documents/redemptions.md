# SunPLS Redemptions

Redemptions allow any SunPLS holder to exchange SunPLS directly for PLS at the system equilibrium price.

This mechanism creates a **hard economic price floor** for SunPLS and plays a critical role in maintaining long-term stability.

Unlike market trades on decentralized exchanges, redemptions occur directly through the protocol using the system equilibrium price `R`.

```
1 SunPLS → (1 / R) PLS
```

If the market price of SunPLS falls below this value, arbitrage incentives encourage users to redeem SunPLS and restore price equilibrium.

---

# Purpose of Redemptions

Redemptions serve several important functions in the SunPLS protocol.

They:

- create a guaranteed minimum value for SunPLS  
- prevent prolonged price deviations below equilibrium  
- remove excess supply from circulation  
- maintain confidence in the system

Without redemptions, a collateralized stable asset could trade below its intrinsic value for extended periods.

Redemptions eliminate this possibility.

---

# Redemption Price

The redemption price is determined by the **equilibrium price `R`** maintained by the Controller.

```
Redemption Rate = 1 / R
```

Example:

```
R = 1.02 PLS per SunPLS
```

Then:

```
1 SunPLS → 0.98039 PLS
```

This value reflects the current equilibrium relationship between SunPLS and its collateral.

---

# Redemption Flow

The redemption process follows a deterministic sequence.

```
User holds SunPLS
↓
User calls redeem()
↓
Protocol selects a vault
↓
SunPLS debt reduced
↓
Vault collateral reduced
↓
User receives PLS
```

The redeemed SunPLS is effectively removed from circulation because it cancels vault debt.

---

# Vault Selection

When a redemption occurs, the protocol selects a vault to source the collateral.

Vault selection is designed to avoid disproportionately harming individual vaults.

Common selection strategies include:

- highest collateral ratio first
- oldest vault first
- sequential vault processing

In many implementations, vaults with the **highest collateral ratio** are selected first.

This keeps the system balanced by gradually reducing excess collateralization.

---

# Redemption Example

```
User redeems: 100 SunPLS
Equilibrium price: R = 1 PLS per SunPLS
```

Result:

```
User receives: 100 PLS
Vault debt reduced by 100 SunPLS
Vault collateral reduced by 100 PLS
```

Total SunPLS supply decreases because the redeemed tokens cancel outstanding vault debt.

---

# Price Floor Mechanism

Redemptions create a natural arbitrage opportunity when SunPLS trades below equilibrium.

Example:

```
DEX price = 0.90 PLS per SunPLS
Redemption value = 1.00 PLS per SunPLS
```

Arbitrage strategy:

```
Buy SunPLS for 0.90 PLS
Redeem for 1.00 PLS
Profit = 0.10 PLS
```

This process continues until market price returns toward equilibrium.

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
collateral ratios increase
```

These dynamics improve overall system safety.

---

# Redemption Fees

Some implementations include a **small redemption fee**.

Purpose of the fee:

- compensate affected vault owners
- discourage excessive redemption activity
- reduce economic manipulation

Example:

```
Redemption Fee = 0.5%
```

If a user redeems 100 SunPLS:

```
User receives: 99.5 PLS
Vault owner receives: 0.5 PLS
```

Fees are typically small to preserve strong arbitrage incentives.

---

# System Effects

Redemptions affect several key system metrics.

| Metric | Impact |
|------|------|
| Total Supply | decreases |
| Vault Debt | decreases |
| Vault Collateral | decreases |
| Average CR | typically increases |
| Market Price | pushed toward equilibrium |

These effects contribute to long-term system stability.

---

# Interaction With the Controller

The controller adjusts borrowing rates based on price deviations.

Redemptions complement this mechanism.

Controller effect:

```
adjust borrowing incentives
```

Redemption effect:

```
directly remove excess supply
```

Together they create a **dual stabilization system**.

---

# Relationship With Liquidations

Liquidations and redemptions serve different roles.

| Mechanism | Purpose |
|----------|---------|
| Liquidations | remove unsafe vaults |
| Redemptions | correct market price deviations |

Liquidations protect solvency.

Redemptions protect price stability.

Both mechanisms work together to maintain system integrity.

---

# Redemption Limits

Protocols may implement safeguards such as:

- maximum redemption size per transaction
- per-epoch redemption limits
- gas cost protections

These measures prevent system abuse and reduce MEV risks.

---

# Security Considerations

Redemptions must be carefully designed to avoid:

- manipulation of vault ordering
- griefing attacks on vault owners
- excessive gas costs

SunPLS implementations typically enforce:

- deterministic vault selection
- atomic execution
- clear accounting rules

---

# Example Market Scenario

Consider the following situation:

```
SunPLS market price drops to 0.95 PLS
Equilibrium price R = 1.00
```

Arbitrage occurs:

```
Traders buy SunPLS
↓
Redeem for collateral
↓
SunPLS supply shrinks
↓
Price returns toward 1.00
```

This mechanism stabilizes the protocol without centralized intervention.

---

# Summary

Redemptions provide the **price floor mechanism** of the SunPLS protocol.

They ensure that:

- SunPLS retains intrinsic value
- supply contracts when price falls
- arbitrage restores market equilibrium

Combined with vault liquidations and controller-based monetary policy, redemptions form a key component of SunPLS’ autonomous stabilization system.
