# SunPLS Architecture

SunPLS is designed as a **minimal autonomous monetary protocol**.  
Its architecture intentionally limits the number of system components in order to reduce complexity, minimize attack surface, and make the economic feedback loop easier to verify.

The system operates through five primary modules:

```
Oracle → Controller → Vault → Liquidations
              ↑
              └──── Redemptions
```

Each component has a clearly defined role and interacts through deterministic rules.

---

# System Components

## Oracle

The Oracle provides the **external price signal `P`**, representing the market price of SunPLS relative to PLS.

Responsibilities:

- read market price from the liquidity pool
- compute a TWAP-based price
- expose `update()`, `peek()`, and health status
- protect against flash-loan manipulation
- degrade gracefully if price updates fail

The Oracle is the **only external input into the system**.

All other protocol behavior is derived from this signal.

---

## Controller

The Controller is the **monetary policy engine** of SunPLS.

It compares the market price `P` with the internal equilibrium price `R` and adjusts the system interest rate `r`.

Core feedback rule:

```
ε = P − R
Δr = K × (ε / R)
```

Controller effects:

- If **P > R**, borrowing becomes more expensive  
- If **P < R**, borrowing becomes cheaper  

This creates an automatic feedback loop that drives the market price toward equilibrium.

Additional safeguards implemented in SunPLS include:

- deadband filtering
- rate limiting
- oracle degradation modes
- dynamic controller gain decay
- emergency system protection
- bounded equilibrium price movement

The Controller acts as a **deterministic monetary policy engine**.

---

## Vault

The Vault module manages **collateralized borrowing**.

Users deposit PLS and mint SunPLS against their collateral.

Key properties:

- overcollateralized minting
- deterministic collateral ratios
- automatic liquidation when vault safety thresholds are violated
- real-time tracking of collateral and debt

Vaults are the primary mechanism through which SunPLS enters circulation.

---

## Liquidations

Liquidations remove unsafe vaults from the system.

When a vault’s collateral ratio falls below the liquidation threshold:

```
CR < LiquidationCR
```

any user can trigger a liquidation.

Process:

1. liquidator repays SunPLS debt
2. vault collateral is transferred to the liquidator
3. vault debt and collateral are cleared

Liquidations ensure that:

- the system remains fully collateralized
- unsafe debt is removed quickly
- economic incentives enforce system safety

---

## Redemptions

Redemptions allow users to exchange SunPLS directly for PLS at the system equilibrium price `R`.

```
1 SunPLS → (1 / R) PLS
```

This creates a **hard economic price floor**.

If market price falls below redemption value:

```
buy SunPLS cheaply
→ redeem for collateral
→ profit
```

This arbitrage mechanism naturally pushes the market price back toward equilibrium.

---

# Monetary Feedback Loop

SunPLS forms a closed economic feedback loop.

```
Market Price (P)
        ↓
Controller compares P vs R
        ↓
Interest rate r adjusts
        ↓
Borrowing incentives change
        ↓
SunPLS supply adjusts
        ↓
Market price moves toward equilibrium
```

At the same time:

```
Unsafe vaults → liquidations remove debt
Cheap SunPLS → redemptions remove supply
```

Together these mechanisms maintain system stability without external governance.

---

# Design Goals

SunPLS architecture prioritizes four goals.

### Simplicity

Fewer components reduce complexity and risk.

### Determinism

All policy decisions follow predefined rules.

### Permissionlessness

Anyone can:

- mint
- liquidate
- redeem
- trigger controller epochs

### Autonomy

Once deployed, the system operates **without administrative intervention**.

---

# System Properties

SunPLS attempts to achieve the following properties:

- overcollateralized stability
- algorithmic monetary policy
- permissionless enforcement
- deterministic system rules
- transparent on-chain telemetry

Together these characteristics move the protocol toward a new class of financial infrastructure:

**Autonomous Monetary Protocols (AMPs)**.

---

# Experimental Status

SunPLS is an experimental system designed to explore whether:

- feedback-controlled interest rates
- collateralized vaults
- permissionless liquidations
- redemption arbitrage

can together produce a **self-stabilizing digital asset without centralized control**.

Its behavior under real market conditions will determine the viability of this model.
