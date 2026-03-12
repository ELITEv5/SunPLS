# SunPLS Liquidations

Liquidations are the primary safety mechanism of the SunPLS protocol.

They ensure that the system remains fully collateralized by removing unsafe vaults and returning collateral to the market.

Whenever a vault's collateral ratio falls below the required safety threshold, anyone can trigger a liquidation.

This mechanism guarantees that:

- SunPLS remains fully backed by collateral
- unsafe debt is removed from the system
- economic incentives enforce system solvency

Liquidations are entirely permissionless and executed through deterministic smart contract logic.

---

# Collateral Ratio

Each vault maintains a **Collateral Ratio (CR)**.

```
CR = (collateral × 1e18 × 100) / (debt × price)
```

Where:

| Variable | Meaning |
|--------|--------|
| `collateral` | WPLS deposited in the vault |
| `debt` | total SunPLS minted from the vault |
| `price` | oracle price in WPLS per SunPLS (1e18 scale) |

Example (price = 97,500 PLS per SunPLS):

```
Vault collateral: 16,537,500 PLS
Vault debt: 0.1 SunPLS
CR = (16,537,500e18 × 1e18 × 100) / (0.1e18 × 97,500e18) = 170%
```

A higher collateral ratio indicates a safer vault.

---

# Liquidation Threshold

SunPLS defines a minimum safe collateral ratio.

```
LIQUIDATION_RATIO = 110%
```

If a vault falls below this threshold:

```
CR < 110%
```

the vault becomes **liquidatable**.

Any participant can then repay part or all of the vault's debt and claim collateral plus a bonus.

---

# Liquidation Flow

The liquidation process occurs as a single atomic transaction.

```
Vault CR falls below 110%
↓
Liquidator calls liquidate(user, repayAmount)
↓
Protocol verifies vault is eligible and cooldown has passed
↓
Liquidator burns SunPLS to repay vault debt
↓
Liquidator receives PLS collateral + Dutch auction bonus
↓
Vault debt and collateral reduced
↓
If vault recovers above 110%, undercollateralizedSince cleared
```

This process removes risky positions from the system immediately.

---

# Dutch Auction Bonus

SunPLS uses a **Dutch auction liquidation bonus** that grows over time.

```
MIN_BONUS_BPS = 200   (2%)
MAX_BONUS_BPS = 500   (5%)
AUCTION_TIME  = 3 hours
```

The bonus starts at 2% and grows linearly to 5% over 3 hours, measured from when the vault **first became undercollateralized** — not from when the liquidation is called.

```
elapsed = block.timestamp − undercollateralizedSince
bonusBps = MIN_BONUS_BPS + (MAX_BONUS_BPS − MIN_BONUS_BPS) × elapsed / AUCTION_TIME
```

Liquidation reward:

```
base(PLS) = repayAmount(SunPLS) × price / 1e18
bonus     = base × bonusBps / 10000
reward    = base + bonus
```

This mechanism incentivizes liquidators to act promptly while ensuring a minimum return even for immediate liquidations.

If `reward > vault.collateral` (underwater vault), the liquidator receives all remaining collateral and the deficit is recorded in `badDebt`.

---

# Partial Liquidations

SunPLS enforces a **minimum liquidation size** of 20% of vault debt.

```
MIN_LIQUIDATION_BPS = 2000  (20%)
repayAmount ≥ vault.debt × 20%
```

This ensures liquidations are economically meaningful and reduce gas overhead per unit of debt cleared.

Example:

```
Vault debt: 1.0 SunPLS
Minimum liquidation: 0.2 SunPLS
```

After a partial liquidation the vault may remain open at a higher CR if the remaining collateral supports it.

---

# Liquidation Cooldown

To prevent repeated rapid liquidations of the same vault, the protocol enforces a **cooldown period**.

```
LIQUIDATION_COOLDOWN = 600 seconds (10 minutes)
```

After each liquidation, the same vault cannot be liquidated again for 10 minutes. This reduces liquidation spam and front-running wars while leaving sufficient time for follow-up liquidations on deeply distressed vaults.

---

# Redemption-Liquidation Gap

A vault that has recently been redeemed against cannot be immediately liquidated.

```
REDEMPTION_LIQUIDATION_GAP = 300 seconds (5 minutes)
```

After a redemption reduces a vault's collateral, the vault owner has 5 minutes to respond — by adding collateral or repaying debt — before liquidators can act.

This prevents atomic redemption → liquidation griefing attacks.

---

# System Safety Guarantees

Liquidations enforce several critical system invariants.

| Invariant | Description |
|---------|-------------|
| Permissionless enforcement | anyone can liquidate eligible vaults |
| Deterministic eligibility | CR < 110% is the only condition |
| Minimum size enforced | liquidations must be at least 20% of debt |
| Bad debt recorded | deficits tracked in `badDebt`, never silent |
| Cooldown protection | 10-minute gap between successive liquidations |
| Redemption gap | 5-minute window after redemption before liquidation |

---

# Oracle Role

The oracle determines the collateral value used in liquidation eligibility checks.

```
CR = (collateral × 1e18 × 100) / (debt × price)
```

Liquidation eligibility uses `_viewPrice()` (oracle peek) rather than `_safePrice()`. This means the volatility filter that protects minting and withdrawal does not apply — liquidations see the real current price, not a smoothed version. This is intentional: the system should liquidate based on actual market conditions.

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
debt removed, collateral returned to liquidators
↓
system solvency restored
```

---

# Liquidator Competition

Liquidations are permissionless.

Multiple participants may compete to liquidate the same vault.

Typical dynamics:

```
bots monitor vault health via getVaultCount() / getVaultOwner()
↓
unsafe vault detected
↓
first valid liquidation transaction wins
```

The on-chain vault enumeration registry (`getVaultCount()`, `getVaultOwner(index)`) allows liquidators and bots to enumerate all vaults without relying on RPC event log scanning.

---

# Economic Impact

Liquidations serve several important economic functions.

They:

- remove unsafe leverage
- return collateral to the market
- maintain full collateral backing
- discourage excessive borrowing relative to collateral value

---

# Example Liquidation

```
price = 97,500 PLS per SunPLS
Vault collateral: 10,530,000 PLS
Vault debt: 0.1 SunPLS
CR = (10,530,000e18 × 1e18 × 100) / (0.1e18 × 97,500e18) = 108%

Vault is liquidatable (CR < 110%).
undercollateralizedSince set 90 minutes ago.

Liquidator repays:
0.02 SunPLS (20% minimum)

base  = 0.02e18 × 97,500e18 / 1e18 = 1,950 PLS
elapsed = 90 min → bonusBps = 200 + (300 × 90/180) = 350 bps (3.5%)
bonus = 1,950 × 350 / 10000 = 68.25 PLS
reward = 2,018.25 PLS

Liquidator receives 2,018.25 PLS.
Vault debt reduced by 0.02 SunPLS.
Vault collateral reduced by 2,018.25 PLS.
```

---

# Relationship to Other Modules

| Module | Role |
|------|------|
| Oracle | determines collateral price for CR calculation |
| Vault System | tracks collateral, debt, and cooldown timestamps |
| Controller | influences borrowing incentives to prevent vaults reaching 110% |
| Redemptions | reduce debt and collateral in distressed vaults (CR ≤ 130%) before liquidation threshold is reached |

---

# Summary

Liquidations are essential to the SunPLS system.

They guarantee that:

- unsafe vaults are removed when CR falls below 110%
- collateral backing is maintained at all times
- bad debt is recorded transparently when it occurs
- liquidators are compensated through a growing Dutch auction bonus
- vault owners have protected windows to respond after redemptions

By combining overcollateralized borrowing with permissionless liquidations, SunPLS ensures that the protocol remains economically secure even during volatile market conditions.
