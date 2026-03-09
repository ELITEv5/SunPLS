# SunPLS Liquidations

Liquidations are the primary safety mechanism of the SunPLS protocol.

They ensure that the system remains fully collateralized by removing unsafe vaults and returning collateral to the market.

Whenever a vault’s collateral ratio falls below the required safety threshold, anyone can trigger a liquidation.

This mechanism guarantees that:

- SunPLS remains fully backed by collateral
- unsafe debt is removed from the system
- economic incentives enforce system solvency

Liquidations are entirely permissionless and executed through deterministic smart contract logic.

---

# Collateral Ratio

Each vault maintains a **Collateral Ratio (CR)**.

```
CR = collateral_value / debt
```

Where:

| Variable | Meaning |
|--------|--------|
| `collateral_value` | value of deposited PLS according to the oracle |
| `debt` | total SunPLS minted from the vault |

Example:

```
Vault collateral: 150 PLS
Vault debt: 100 SunPLS
CR = 150%
```

A higher collateral ratio indicates a safer vault.

---

# Liquidation Threshold

SunPLS defines a minimum safe collateral ratio.

Example:

```
Liquidation Threshold = 110%
```

If a vault falls below this threshold:

```
CR < 110%
```

the vault becomes **liquidatable**.

This means any participant can close the vault and claim its collateral.

---

# Liquidation Flow

The liquidation process occurs as a single atomic transaction.

```
Vault becomes unsafe
↓
Liquidator calls liquidation function
↓
Liquidator repays part or all of the vault's SunPLS debt
↓
Liquidator receives PLS collateral + liquidation bonus
↓
Vault debt and collateral updated
```

This process removes risky positions from the system immediately.

---

# Liquidation Incentives

Liquidations are enforced through economic incentives.

Liquidators receive:

```
Collateral seized + liquidation bonus
```

The bonus compensates liquidators for:

- gas costs
- transaction risk
- market volatility

This ensures that unsafe vaults are quickly removed even during extreme market conditions.

---

# Partial Liquidations

SunPLS may allow **partial liquidations**.

In this case:

```
liquidator repays minimum portion of debt
vault collateral reduced proportionally
vault becomes safer
```

Example:

```
Vault debt: 100 SunPLS
Minimum liquidation: 20 SunPLS
```

Liquidator repays 20 SunPLS and receives the corresponding collateral.

Partial liquidations help stabilize vaults without fully closing them.

---

# Dutch Auction Bonus (Optional Mechanism)

Some implementations include a **Dutch auction liquidation bonus**.

This means:

```
initial bonus = high
bonus decreases over time
```

Early liquidators receive higher rewards, encouraging rapid liquidation of unsafe vaults.

This mechanism helps ensure liquidations occur quickly during volatile market conditions.

---

# Liquidation Cooldown

To prevent repeated rapid liquidations of the same vault, the protocol may enforce a **cooldown period**.

```
LIQUIDATION_COOLDOWN
```

During this period the vault cannot be liquidated again.

Cooldowns reduce:

- liquidation spam
- front-running wars
- unnecessary gas consumption

---

# System Safety Guarantees

Liquidations enforce several critical system invariants.

| Invariant | Description |
|---------|-------------|
| No Bad Debt | debt is always backed by collateral |
| Permissionless Enforcement | anyone can liquidate unsafe vaults |
| Deterministic Rules | liquidation conditions are transparent |
| Immediate Correction | unsafe vaults are removed quickly |

These guarantees are essential for maintaining trust in the protocol.

---

# Oracle Role

The oracle determines the collateral value used in liquidation calculations.

```
CR = collateral × oracle_price / debt
```

Because liquidations depend on oracle data, the protocol includes protections against:

- stale prices
- price manipulation
- oracle outages

The controller also includes fallback modes to handle degraded oracle conditions.

---

# Market Dynamics

Liquidations naturally occur during market downturns.

Example scenario:

```
PLS price drops
↓
vault CR decreases
↓
some vaults fall below 110%
↓
liquidations triggered
↓
system removes risky debt
```

This mechanism helps restore system stability.

---

# Liquidator Competition

Liquidations are permissionless.

Multiple participants may compete to liquidate the same vault.

Typical dynamics:

```
bots monitor vault health
↓
unsafe vault detected
↓
first valid liquidation transaction wins
```

This competitive process ensures rapid enforcement of system safety.

---

# Economic Impact

Liquidations serve several important economic functions.

They:

- remove unsafe leverage
- return collateral to the market
- maintain collateral backing
- discourage excessive borrowing

These effects stabilize the protocol during periods of volatility.

---

# Example Liquidation

```
Vault collateral: 120 PLS
Vault debt: 110 SunPLS
CR = 109%

Vault becomes liquidatable.

Liquidator repays:
20 SunPLS

Liquidator receives:
≈ 22 PLS (including bonus)

Vault updated:
Collateral reduced
Debt reduced
CR increases
```

The system returns to a safer state.

---

# Relationship to Other Modules

Liquidations interact with several protocol components.

| Module | Role |
|------|------|
| Oracle | determines collateral price |
| Vault System | tracks collateral and debt |
| Controller | influences borrowing incentives |
| Redemptions | provide additional supply reduction |

Together these modules maintain the protocol’s stability.

---

# Security Considerations

Key security properties of SunPLS liquidations include:

- atomic execution
- no external price dependence during liquidation
- deterministic eligibility rules
- permissionless enforcement

These properties reduce the attack surface and ensure predictable behavior.

---

# Summary

Liquidations are essential to the SunPLS system.

They guarantee that:

- unsafe vaults are removed
- collateral backing is maintained
- the system remains solvent

By combining overcollateralized borrowing with permissionless liquidations, SunPLS ensures that the protocol remains economically secure even during volatile market conditions.
