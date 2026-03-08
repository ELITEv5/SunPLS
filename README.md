# ☀️ SunPLS — Autonomous Stable Asset (Experimental)

SunPLS is an experimental **autonomous stable asset protocol** built for PulseChain.

The system combines:

- Over-collateralized vaults
- Direct redemption against collateral
- Dutch-auction liquidations
- Autonomous monetary policy

Together these mechanisms form a **self-regulating monetary system** designed to operate without governance or administrative control.

SunPLS was developed following the **ProjectUSD specification guidelines**, which define the architecture and invariants required for building resilient autonomous stable assets.

> ⚠️ **Experimental Protocol**  
> SunPLS is a research implementation of the ProjectUSD architecture and should not be considered production financial infrastructure.

---

# Table of Contents

- Overview
- ProjectUSD Specification
- System Architecture
- Core Components
- Stability Mechanisms
- Redemption Mechanism
- Liquidation System
- Controller Epochs
- Example Vault Flow
- System Invariants
- Design Goals
- Deployment
- Experimental Status
- License
- Disclaimer
- Acknowledgements

---

# Overview

SunPLS is designed as a **closed-loop autonomous monetary system**.

The protocol continuously observes market price and adjusts economic incentives through an automated controller.

```
Market Price (P)
       ↓
Controller Policy
       ↓
Interest Rate (r)
       ↓
Vault Incentives
       ↓
Supply Changes
       ↓
Market Price
       ↺
```

This feedback loop allows the system to dynamically adjust borrowing incentives and supply conditions in response to market deviation.

---

# ProjectUSD Specification

SunPLS follows the **ProjectUSD architecture specification**.

ProjectUSD defines a framework for building **fully autonomous stable assets** that operate without discretionary governance.

The specification emphasizes:

- Deterministic monetary policy
- Immutable contracts
- Oracle resilience
- Closed-loop stability control
- Economic safety invariants
- System liveness under degraded conditions

SunPLS represents an **experimental implementation** of these design principles.

---

# System Architecture

The SunPLS protocol is composed of four core components:

```
        SunPLS Token
              │
              ▼
          Price Oracle
              │
              ▼
      Monetary Controller
              │
              ▼
          Vault System
```

Each component performs a dedicated role in maintaining system stability.

---

# Core Components

## SunPLS Token

SunPLS is the stable asset minted by vaults when collateral is deposited.

Properties:

- ERC-20 token
- Minted when collateralized debt is created
- Burned during repayment, redemption, or liquidation

The token supply expands and contracts based on vault activity.

---

## Vault (CDP System)

The vault contract implements **collateralized debt positions (CDPs)**.

Users deposit PLS (wrapped as WPLS) and mint SunPLS against collateral.

### Vault Parameters

- Minimum collateral ratio: **150%**
- Liquidation threshold: **110%**
- Redemption eligibility: **≤150%**
- Minimum liquidation size: **20% of vault debt**
- Withdrawal cooldown: **5 minutes**

Vaults enforce **strict on-chain solvency rules**.

---

## Controller

The controller implements an **autonomous monetary policy engine**.

It adjusts the system interest rate based on price deviation.

```
ε = |P − R|
Δr = K × ε
```

Where:

- **P** = oracle market price  
- **R** = redemption value  
- **r** = system interest rate  

### Controller Features

- Proportional feedback control
- Deadband to ignore small deviations
- Rate change limiter
- Redemption value damping
- Epoch-based updates
- Oracle degradation handling

This mechanism approximates **automated central-bank-style policy adjustments**.

---

## Oracle

The oracle provides the market price signal required by the controller.

To prevent system failure during oracle outages, the controller supports **four degradation modes**.

| Mode | Description |
|-----|-------------|
| A | Fresh oracle update |
| B | Peek fallback price |
| C | Stored price buffer |
| D | Frozen epoch |

These mechanisms ensure the system remains **live even during oracle disruption**.

---

# Stability Mechanisms

SunPLS stability relies on **three independent layers**.

```
Layer 1 — Collateralized Vaults
Layer 2 — Redemption Arbitrage
Layer 3 — Autonomous Controller
```

These mechanisms reinforce each other to maintain system equilibrium.

---

# Redemption Mechanism

SunPLS holders can redeem tokens directly against vault collateral.

```
PLS_out = SunPLS × R
```

Where **R** is the redemption value determined by the controller.

If SunPLS trades below redemption value:

```
Buy SunPLS
Redeem for PLS
Profit
```

This creates a **hard price floor enforced through arbitrage**.

---

# Liquidation System

Vaults below the liquidation threshold become eligible for liquidation.

SunPLS uses a **Dutch-auction liquidation incentive**.

```
bonus = 2% → 5%
duration = 3 hours
```

The liquidation reward increases over time until the vault is resolved.

This guarantees strong incentives for liquidators.

---

# Controller Epochs

Monetary policy updates occur once per epoch.

```
triggerEpoch()
```

During each epoch:

1. Oracle price is resolved
2. Price deviation is calculated
3. Interest rate is adjusted
4. Redemption value may move
5. Vault interest rates update

Epoch execution is **permissionless**.

Anyone can trigger an epoch.

---

# Example Vault Flow

User deposits collateral.

```
Deposit: 10,000 PLS
```

Collateral value is calculated.

```
collateralValue = collateral × 1e18 / price
```

User mints SunPLS.

```
Mint: 0.055 SunPLS
```

Vault collateral ratio:

```
CR = collateral / debt
```

If CR falls below 110%, liquidation becomes possible.

---

# System Invariants

The protocol enforces several invariants derived from the ProjectUSD specification.

```
I1 — Vault solvency
I2 — Rate bounds
I3 — Redemption floor
I4 — Oracle resilience
I5 — System liveness
I6 — Immutable contracts
```

These invariants ensure the system remains safe even under degraded conditions.

---

# Design Goals

SunPLS was designed with the following goals:

- Fully autonomous monetary policy
- No governance control
- Deterministic economic rules
- Strong arbitrage stabilization
- Oracle failure resilience
- Permissionless operation

The protocol behaves as a **self-contained economic machine**.

---

# Deployment

Deployment order:

```
1. Deploy SunPLS Token
2. Deploy Oracle
3. Deploy Controller
4. Deploy Vault
5. Link token and controller to vault
```

After linking, the system becomes **fully autonomous**.

---

# Experimental Status

SunPLS is an **experimental implementation** of the ProjectUSD architecture.

The protocol is intended for:

- research
- experimentation
- economic modeling
- protocol design exploration

---

# License

CC-BY-NC-SA-4.0

---

# Disclaimer

SunPLS is experimental software provided for research and educational purposes.

No guarantees are made regarding financial stability, economic behavior, or security.

Use at your own risk.

---

# Acknowledgements

SunPLS was developed following the **ProjectUSD autonomous stable asset specification**, which provided the design framework and safety invariants used to construct the protocol architecture.
