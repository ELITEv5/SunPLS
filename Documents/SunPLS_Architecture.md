# SunPLS Architecture

SunPLS is an experimental autonomous monetary protocol built on PulseChain.

The protocol combines:

- overcollateralized vaults
- algorithmic monetary policy
- permissionless liquidations
- redemption arbitrage

to create a self-stabilizing digital asset.

SunPLS draws conceptual inspiration from the **ProjectUSD specification**, particularly its feedback-based stabilization design, while intentionally simplifying the system architecture to reduce complexity and attack surface.

---

# Design Philosophy

SunPLS prioritizes four core principles:

### Simplicity

The protocol intentionally minimizes system components.  
Fewer modules reduce the number of potential failure points and simplify security analysis.

### Determinism

All monetary policy decisions are executed by predefined algorithmic rules.

### Permissionlessness

Anyone can interact with the system by:

- minting SunPLS
- redeeming SunPLS
- liquidating unsafe vaults
- triggering controller epochs

### Autonomy

Once deployed, the protocol operates without administrative control or governance intervention.

---

# System Overview

SunPLS operates through five primary modules.

```
Oracle → Controller → Vault System → Liquidations
               ↑
               └────────── Redemptions
```

Each component has a clearly defined responsibility.

---

# Core Components

## Oracle

The Oracle provides the **external market price P**.

Responsibilities:

- read SunPLS/WPLS price from the PulseX liquidity pool
- compute a TWAP-based price
- expose price through `update()` and `peek()`
- detect stale or invalid price feeds
- provide health status for the controller

Price is expressed in **WPLS per SunPLS** (1e18 scale).

The Oracle is the **only external input into the protocol**.

All other system behavior derives from this signal.

---

## Controller

The Controller is the **monetary policy engine** of SunPLS.

It compares:

```
P = market price (WPLS per SunPLS)
R = internal equilibrium value (WPLS per SunPLS)
```

and adjusts the system interest rate `r`.

Core feedback rule:

```
ε = |P − R| / R  (normalized deviation)
Δr = K × ε
```

The Controller ensures that borrowing conditions dynamically adjust to market price deviations.

Key controller features:

- deadband filtering (ignore deviations below 0.1%)
- rate limiter (max 0.05% change per epoch)
- dynamic gain decay (K decays as oracle age increases)
- four-mode oracle fallback (A → B → C → D)
- emergency system protection (forces MAX_RATE below 120% system health)
- bounded equilibrium value movement (R capped at 10% per epoch)

The controller executes once per **epoch** (1 hour).

---

## Vault System

Vaults allow users to mint SunPLS by depositing PLS collateral.

Users can:

- deposit PLS
- mint SunPLS
- repay debt
- withdraw collateral

Vaults must remain above the required collateral ratio.

### Vault CR Zones

| CR Range | Status |
|---|---|
| Above 150% | Healthy. Immune to redemption. Can mint and withdraw. |
| 130%–150% | Distressed. Redemption eligible. Cannot mint more. |
| 110%–130% | Seriously distressed. Redemption eligible. Approaching liquidation. |
| Below 110% | Liquidatable. Dutch auction active. |

---

## Liquidations

Liquidations remove unsafe vaults from the system.

Condition:

```
CR < 110%
```

Where:

```
CR = (collateral × 1e18 × 100) / (debt × price)
```

Liquidation process:

1. liquidator repays SunPLS debt
2. vault collateral transferred to liquidator (plus 2%–5% bonus)
3. vault debt and collateral reduced accordingly

Bonus grows from 2% to 5% over 3 hours via Dutch auction, incentivizing timely resolution.

Liquidations guarantee:

- system solvency
- full collateral backing
- economic enforcement of safety

---

## Redemptions

Redemptions allow users to exchange SunPLS directly for PLS at the current value of R.

```
PLS received = SunPLS burned × R
```

Only vaults at or below **130% CR** can be redeemed against. Vaults above 130% CR are completely immune.

If SunPLS trades below R:

```
buy SunPLS on market
redeem against a distressed vault (CR ≤ 130%)
receive PLS at R value
profit
```

This arbitrage mechanism creates pressure that converges market price toward R. R itself is a derived system state, not a guaranteed bound — it moves as the controller responds to sustained deviation.

A 0.5% fee is retained by the vault owner. A 5-minute window after redemption prevents immediate liquidation, giving vault owners time to respond.

---

# Monetary Feedback Loop

SunPLS forms a closed economic feedback system.

```
Market Price (P)
        ↓
Controller compares P vs R
        ↓
Interest rate r adjusts
        ↓
Borrowing incentives change
        ↓
SunPLS supply changes
        ↓
Market price moves toward equilibrium
```

Simultaneously:

```
Unsafe vaults (CR < 110%) → liquidations remove debt
Cheap SunPLS + distressed vaults (CR ≤ 130%) → redemptions remove supply
```

Together these forces stabilize the system.

---

# Key Protocol Properties

SunPLS attempts to maintain the following properties:

### Overcollateralization

Every SunPLS token is backed by excess collateral.

### Deterministic Policy

Monetary policy is executed entirely by code.

### Transparent Operation

All system variables are publicly visible on-chain.

### Permissionless Enforcement

Safety is enforced by open participation rather than centralized actors.

---

# Differences from ProjectUSD

SunPLS draws inspiration from the **ProjectUSD controller specification**, but simplifies several components.

Notable simplifications:

- no stability pool
- no surplus buffer
- no governance parameter updates
- reduced module complexity

This design focuses on creating a **minimal autonomous monetary experiment**.

---

# System Data Flow

```
DEX Price
   ↓
Oracle (TWAP, WPLS per SunPLS)
   ↓
Controller
   ↓
Interest Rate r
   ↓
Vault Borrowing Incentives
   ↓
SunPLS Supply
   ↓
Market Price
```

Safety mechanisms operate alongside the main loop:

```
Vault CR < 110%  → Liquidations remove debt
Vault CR ≤ 130%  → Redemptions remove supply
Market Price ↓   → Redemption arbitrage restores equilibrium
```

---

# Experimental Nature

SunPLS is an experimental protocol exploring whether:

- algorithmic interest rate control
- overcollateralized borrowing
- permissionless liquidations
- redemption arbitrage

can produce a **self-stabilizing digital asset without centralized monetary control**.

The long-term behavior of such systems can only be evaluated through real-world operation.

---

# References

Conceptual inspiration:

ProjectUSD Whitepaper V2.1  
ProjectUSD Controller Specification  
ProjectUSD Stability Model Research
