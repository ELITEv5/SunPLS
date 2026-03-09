# SunPLS FAQ

This document answers common questions about the SunPLS protocol.

SunPLS is an experimental autonomous monetary system built on PulseChain.  
It combines overcollateralized vaults, algorithmic monetary policy, and permissionless liquidations to explore a new class of decentralized financial infrastructure.

Many design ideas are inspired by the **ProjectUSD research specifications**, particularly its feedback-based stabilization model.

---

# What is SunPLS?

SunPLS is an overcollateralized digital asset that attempts to maintain a stable value relative to PLS using algorithmic monetary policy.

Users can mint SunPLS by depositing PLS into vaults.

The protocol then uses:

- controller-based interest rate adjustments
- vault liquidations
- redemption arbitrage

to maintain price stability.

---

# How is SunPLS different from traditional stablecoins?

Traditional stablecoins rely on one of the following:

| Model | Example |
|------|--------|
| Fiat-backed | USDC |
| Algorithmic supply | early algorithmic stablecoins |
| Stability pool liquidation | Liquity |

SunPLS instead uses a **feedback-based monetary policy system** inspired by ProjectUSD.

The system adjusts borrowing rates based on price deviations rather than targeting a fixed supply.

---

# What keeps SunPLS stable?

SunPLS stability comes from four mechanisms working together.

### 1. Overcollateralized vaults

All SunPLS must be minted against PLS collateral.

This ensures that the system remains fully backed.

---

### 2. Algorithmic interest rates

The Controller adjusts borrowing rates depending on market price deviations.

If SunPLS trades above equilibrium:

```
borrowing becomes more expensive
```

If SunPLS trades below equilibrium:

```
borrowing becomes cheaper
```

This changes supply incentives.

---

### 3. Liquidations

Unsafe vaults are liquidated automatically when their collateral ratio falls below the required threshold.

Liquidators repay SunPLS debt and receive collateral.

This keeps the system solvent.

---

### 4. Redemptions

SunPLS can always be redeemed for PLS at the system equilibrium price.

If the market price drops below this value, traders can buy SunPLS cheaply and redeem it for collateral.

This creates a natural price floor.

---

# What is the Controller?

The Controller is the protocol’s monetary policy engine.

It compares:

```
P = market price
R = equilibrium price
```

Then adjusts the borrowing rate `r`.

Controller equation:

```
Δr = K × (ε / R)
```

Where:

```
ε = P − R
```

This creates a feedback loop that pushes market price toward equilibrium.

---

# What is the equilibrium price R?

`R` is the internal reference price used by the system.

It determines:

- redemption value
- monetary policy calculations

The equilibrium price can move slowly over time as the system adapts to market conditions.

---

# What happens if PLS price crashes?

If the price of PLS falls sharply:

- vault collateral ratios decrease
- unsafe vaults become liquidatable
- liquidators remove risky positions

This process removes debt and restores system safety.

However, extreme collateral crashes may cause rapid liquidation events.

---

# Who can liquidate vaults?

Anyone can liquidate unsafe vaults.

Liquidations are permissionless.

Participants who perform liquidations receive collateral rewards.

This ensures unsafe vaults are removed quickly.

---

# Who triggers controller updates?

Controller updates are also permissionless.

Any user can trigger a new epoch once the epoch duration has passed.

This keeps the system decentralized and operational without relying on specific actors.

---

# Is there governance?

SunPLS is designed to minimize governance.

Most parameters are fixed at deployment and enforced by smart contracts.

This reduces governance risks and keeps the system predictable.

---

# Why is there no stability pool?

Some protocols rely on stability pools to absorb liquidation debt.

SunPLS intentionally avoids this mechanism to reduce complexity.

Instead, liquidators directly repay vault debt in exchange for collateral.

This simplifies the system architecture.

---

# Is SunPLS fully decentralized?

SunPLS aims to operate as an autonomous protocol.

Once deployed:

- contracts enforce all rules
- monetary policy runs algorithmically
- no administrator controls the system

However, like all DeFi systems, it still depends on:

- blockchain infrastructure
- oracle data
- market liquidity

---

# Is SunPLS risk-free?

No.

SunPLS is an experimental financial protocol.

Risks may include:

- smart contract vulnerabilities
- extreme market volatility
- liquidity disruptions
- unexpected economic behavior

Users should carefully evaluate these risks before interacting with the protocol.

---

# What happens if the oracle fails?

The protocol includes multiple oracle fallback modes.

Possible responses include:

- using stored price data
- reducing controller sensitivity
- freezing rate updates temporarily

These mechanisms prevent incorrect monetary policy decisions during oracle disruptions.

---

# Why is SunPLS experimental?

Autonomous monetary systems are still an emerging field in decentralized finance.

SunPLS explores whether:

- feedback-controlled interest rates
- collateralized vault systems
- permissionless enforcement

can produce a stable digital asset without centralized management.

The long-term behavior of such systems can only be evaluated through real-world operation.

---

# Where can I see the protocol state?

All key system variables are publicly visible on-chain.

These include:

- equilibrium price `R`
- borrowing rate `r`
- vault collateral ratios
- oracle price data
- controller telemetry

This transparency allows independent verification of protocol health.

---

# Summary

SunPLS is an experimental decentralized monetary protocol that combines:

- overcollateralized lending
- algorithmic interest rate control
- permissionless liquidations
- redemption arbitrage

to explore the possibility of a self-stabilizing digital asset.

The protocol’s design draws conceptual inspiration from the **ProjectUSD research framework**, while implementing a simplified architecture focused on autonomy and transparency.
