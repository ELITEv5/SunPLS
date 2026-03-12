# ☀️ SunPLS — Autonomous Ownerless Immutable (Experimental)

SunPLS is an experimental **autonomous monetary asset protocol** built for PulseChain.

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
- Intellectual Lineage
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

# Intellectual Lineage

SunPLS sits at the intersection of two independent lines of thinking that arrived 
at the same conclusion 50 years apart.

In 1976, economist Friedrich Hayek published *Denationalisation of Money*, 
arguing that government monopoly on currency issuance was the root cause of 
monetary instability. His proposed solution: competing private currencies that 
earn trust through demonstrated stability — not legal mandate, not institutional 
backing, not governance decisions. Every central bank ignored him. He lacked the 
trustless infrastructure to make it real.

The ProjectUSD specification translated Hayek's vision into a concrete 
architectural framework for autonomous stable assets — defining the P/R/r 
feedback loop, the redemption mechanism, and the closed-loop stability guarantee 
that requires no external reference, no oracle dependency on USD, and no human 
discretion at any point in the system.

SunPLS is the first live implementation of that specification.

The architecture is not pegged to the dollar. It is not pegged to any external 
asset. It defines its own internal equilibrium price R and defends it through 
mathematics. The "bank" is immutable Solidity. The "monetary policy" is 
a proportional controller that executes identically whether it processes 
$100 or $100 million. No board meeting required.

> *"If stablecoins truly become infrastructure then the systems that matter most 
> will be the ones that no one controls."*
> — ProjectUSD specification author

SunPLS is that system.

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
- Redemption eligibility: **≤130%**
- Minimum liquidation size: **20% of vault debt**
- Withdrawal cooldown: **5 minutes**

Vaults enforce **strict on-chain solvency rules**.

### CR Zone Map

| CR Range | Status |
|---|---|
| Above 150% | Healthy. Immune to redemption. Can mint and withdraw. |
| 130%–150% | Distressed. Redemption eligible. Cannot mint more. |
| 110%–130% | Seriously distressed. Redemption eligible. Approaching liquidation. |
| Below 110% | Liquidatable. Dutch auction active. |

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
- **R** = internal equilibrium value  
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

Where **R** is the internal equilibrium value maintained by the controller.

If SunPLS trades below R:

```
Buy SunPLS
Redeem for PLS
Profit
```

This creates **arbitrage pressure that converges market price toward R**. R itself is a derived system state, not a guaranteed bound — it moves as the controller responds to sustained deviation.

### Vault Owner Protection

- Only vaults at or below **130% CR** can be targeted
- Vaults above 130% CR are completely immune to redemption
- A 0.5% fee stays with the vault owner as compensation for involuntary exit
- A 5-minute liquidation gap after redemption gives vault owners time to respond
- Incentivizes vault owners to maintain CR well above 130%

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
CR = collateral × 1e18 × 100 / (debt × price)
```

If CR falls below 110%, liquidation becomes possible.
If CR falls to or below 130%, redemption becomes possible.

---

# System Invariants

The protocol enforces several invariants derived from the ProjectUSD specification.

```
I1  — Vault solvency: CR ≥ 150% to mint or withdraw
I2  — Liquidation: vaults below 110% CR can be liquidated
I3  — Redemption: only vaults at or below 130% CR can be redeemed against
I4  — Price floor: SunPLS can always be redeemed at R-value
I5  — Oracle resilience: lastOraclePrice fallback prevents oracle-bricking
I6  — Rate safety: interest rate bounded by Controller invariants
I7  — Immutability: no admin, no pause, no upgrade after deploy
I8  — Liveness: dead oracle never blocks deposit, repay, or withdraw
I9  — Debt initialization: lastDebtAccrual always set on first debt issuance
I10 — Auction anchor: Dutch auction elapsed measured from undercollateralized start
I11 — Bad debt tracking: residual uncovered debt recorded, never silent
I12 — Redeem-liquidation gap: vault cannot be liquidated within 5 minutes of redemption
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

## Canonical Deployment — v1.4 (Live)

All contracts are immutable. No admin keys. No upgrade paths.
After vault linking both token and controller are permanently latched.

| Contract | Address |
|---|---|
| SunPLS Token v1.3 | `0x04b37fa64a8d73a37D636608e5F6F8E5ce1541Aa` |
| SunPLSOracleV2 v1.2 | `0xc8B4d7d885D41826CB46376676638449332aeA87` |
| ProjectUSDController v4.3 | `0x0e736966F6d0dCd41acd575c3dDece3b3B6033A7` |
| SunPLSVault v1.4 | `0x6521899F840847de88E87A121447FfB7b5aF9aF0` |
| SunPLS/WPLS PLP Pair | `0xca46e01F4bF6938e8d8b8d22a570fFE96E9F0b19` |

Network: **PulseChain** (Chain ID 369)

> ⚠️ Prior deployments (v1.2, v1.3) exist on-chain. v1.2 contained an inverted 
> oracle price formula and is non-functional. v1.3 has been superseded by v1.4 
> which lowers the redemption eligibility threshold from 150% to 130% and adds 
> on-chain vault enumeration. The v1.4 addresses above are the canonical live system.

## Deploy Order
```
1. Deploy SunPLS Token        — constructor mints 1000 SUNPLS to deployer
2. Seed PulseX WPLS/SunPLS pair
3. Deploy Oracle              — reads live pair
4. Deploy Controller          — _initialR = oracle.lastPrice()
5. Deploy Vault
6. token.setVault(vault)      — permanent latch, one-time only
7. controller.setVault(vault) — permanent latch, one-time only
```

After step 7 the system is fully autonomous. No further deployer action 
is possible or required.

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

SunPLS was developed following the **ProjectUSD autonomous stable asset 
specification**, which provided the architectural framework, safety invariants, 
and P/R/r feedback model used to construct the protocol.

ProjectUSD specification: https://github.com/Aqua75/ProjectUSD

The intellectual lineage traces from Hayek's 1976 *Denationalisation of Money* 
through the ProjectUSD specification to this implementation. The spec author and ELITE TEAM6 arrived at compatible conclusions independently — the spec from first-principles reasoning about trustless monetary architecture, the implementation from practical CDP building experience on PulseChain. Notably, the spec author was aware of Hayek but did not realize until later how precisely the specification reproduced his conclusions. This is corroboration, not citation — three independent lines of reasoning converging on the same architecture across 50 years.
