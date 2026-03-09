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

- read SunPLS price from the liquidity pool
- compute a TWAP-based price
- expose price through `update()` and `peek()`
- detect stale or invalid price feeds
- provide health status for the controller

The Oracle is the **only external input into the protocol**.

All other system behavior derives from this signal.

---

## Controller

The Controller is the **monetary policy engine** of SunPLS.

It compares:

```
P = market price
R = equilibrium price
```

and adjusts the system interest rate `r`.

Core feedback rule:

```
ε = P − R
Δr = K × (ε / R)
```

The Controller ensures that borrowing conditions dynamically adjust to market price deviations.

Key controller features:

- deadband filtering
- rate limiter
- dynamic gain decay
- oracle fallback modes
- emergency system protection
- bounded equilibrium price movement

The controller executes once per **epoch** (typically hourly).

---

## Vault System

Vaults allow users to mint SunPLS by depositing PLS collateral.

Users can:

- deposit PLS
- mint SunPLS
- repay debt
- withdraw collateral

Vaults must remain above the required collateral ratio.

If collateralization becomes unsafe, the vault becomes liquidatable.

---

## Liquidations

Liquidations remove unsafe vaults from the system.

Condition:

```
CR < LiquidationThreshold
```

Where:

```
CR = collateral value / debt
```

Liquidation process:

1. liquidator repays SunPLS debt
2. vault collateral is transferred to liquidator
3. vault state resets to zero

Liquidations guarantee:

- system solvency
- full collateral backing
- economic enforcement of safety

---

## Redemptions

Redemptions allow users to exchange SunPLS directly for PLS at the system price.

```
1 SunPLS → (1 / R) PLS
```

Redemptions create a **hard price floor**.

If SunPLS trades below redemption value:

```
buy SunPLS on market
redeem for PLS
profit
```

This arbitrage mechanism pushes the market price back toward equilibrium.

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
Unsafe vaults → liquidations remove debt
Cheap SunPLS → redemptions remove supply
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
Oracle (TWAP)
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
Vault CR ↓ → Liquidations remove debt
Market Price ↓ → Redemptions remove supply
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
