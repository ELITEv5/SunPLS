# SunPLS v1.4 — Live Deployment Update
*March 2026 — ELITE TEAM6*

---

## System Status: Operational

SunPLS v1.4 has been running autonomously on PulseChain mainnet since deployment.

All four contracts are live, immutable, and operating without human intervention.

---

## Deployment Addresses (PulseChain — Chain ID 369)

| Contract | Address |
|---|---|
| SunPLS Token v1.3 | `0x04b37fa64a8d73a37D636608e5F6F8E5ce1541Aa` |
| SunPLS/WPLS LP Pair | `0xca46e01F4bF6938e8d8b8d22a570fFE96E9F0b19` |
| Oracle v1.2 | `0xc8B4d7d885D41826CB46376676638449332aeA87` |
| Controller v4.3 | `0x0e736966F6d0dCd41acd575c3dDece3b3B6033A7` |
| Vault v1.4 | `0x6521899F840847de88E87A121447FfB7b5aF9aF0` |
| Router | `0x165C3410fC91EF562C50559f7d2289fEbed552d9` |
| sSunPLS Auto Stake | `0x9b03a144A3dBaF1bf069474447168A9af54aA6a4` |

---

## Live Telemetry — Epoch 20

The following readings were taken from the deployed Controller contract.

```
Epochs executed:     20
Emergency epochs:    0
Frozen epochs:       0
Oracle fallbacks:    0
Deadband skips:      3
Limiter hits:        0

R (equilibrium):     97,804e18 WPLS per SunPLS
r (current rate):    623e12 (~0.22% APR, positive)
Oracle mode:         A (fresh, full K)
Oracle healthy:      true
Effective K:         100% (10,000 bps)
```

---

## What the Telemetry Means

**20 epochs. Zero failures of any kind.**

Every epoch that has fired has done so cleanly — fresh oracle price, correct rate adjustment, successful vault rate push, epoch advanced. The system has experienced real PulseChain market conditions over several weeks and responded without a single emergency, oracle failure, or frozen epoch.

The 3 deadband skips are healthy — they represent epochs where the market price was within 0.1% of equilibrium and the controller correctly determined no rate adjustment was needed. This is the noise filter working as designed.

Zero limiter hits means the controller has never needed to cap its rate adjustment. The proportional response has been within bounds every single epoch.

---

## Oracle Behavior — Creeping in Action

The oracle is demonstrating its manipulation-resistant design in real time.

```
Genesis R:        ~97,500e18
Current lastPrice: 106,809e18
Current spot:      120,310e18
Total market move: ~23% from genesis
```

The oracle has not jumped to the spot price. It is walking toward it in validated steps — accepting moves within the 5% threshold immediately and requiring three confirmation epochs for larger moves before creeping in 10% steps.

This means a sophisticated actor cannot flash-manipulate the oracle into accepting a fraudulent price. A sustained large move requires hours of confirmed readings across multiple epochs before being fully registered.

The controller is working with `lastPrice = 106,809e18` rather than the spot price of `120,310e18`. The remaining ~12.7% gap will be walked in over subsequent epochs as the creeping mechanism accumulates confirmations.

---

## Rate and Equilibrium Progression

```
Epoch 1:   R ≈ 97,500e18  |  r = 0
Epoch 19:  R = 97,759e18  |  r = 531e12
Epoch 20:  R = 97,804e18  |  r = 623e12
```

R is stepping upward slowly and deliberately as the oracle walks toward the higher market price. The interest rate is rising correctly — market price is above equilibrium, so the controller is making borrowing incrementally more expensive to moderate supply.

This is autonomous monetary policy working exactly as designed. No committee. No vote. No human decision. Just math running on-chain every epoch.

---

## Architecture Validation

The deployment has validated several key design decisions in production:

**Four-mode oracle degradation works.** The system gracefully handled a 10+ hour gap between epoch calls by degrading to Mode B with decayed K, then snapping back to full Mode A on the next fresh update. Zero oracle fallbacks recorded despite sporadic calling patterns.

**Permissionless epoch execution works.** The system has no keeper. Epochs fire whenever someone calls `triggerEpoch()`. The protocol doesn't care who calls it or when — it picks up exactly where it left off every time.

**Vault latch security confirmed.** Both Token and Controller vault latches are permanently closed. `vaultSet = true` on both contracts. No admin authority exists anywhere in the system.

**Creeping anti-manipulation confirmed.** The oracle is actively demonstrating the creeping mechanism on a real ~12.7% price gap, accumulating confirmations rather than accepting the move instantly.

**Emergency system untriggered.** Zero emergency epochs. System health has remained above the 120% threshold throughout. The emergency brake exists but has not been needed.

---

## Epoch Calling Pattern

Epochs are not being called every hour. The system has fired 20 epochs over several weeks — a sporadic, irregular pattern that reflects organic interaction rather than a maintained keeper bot.

This is intentional validation of the permissionless design. The protocol does not require infrastructure maintenance. It waits, indefinitely, for anyone to call `triggerEpoch()`, then executes the full control loop correctly regardless of how much time has passed — subject only to the oracle's price age decay and the 24-hour MAX_P_AGE window.

The autonomous central bank runs on its own schedule.

---

## Relationship to ProjectUSD Specification

SunPLS v1.4 is an independent production implementation conceptually inspired by the ProjectUSD controller specification. The live deployment is contributing real on-chain data to the broader research conversation around autonomous monetary protocols.

Key architectural differences from the ProjectUSD SPEC that have been validated in production:

- **Four-mode oracle degradation** (SPEC defines only STALE → Δr = 0)
- **Linear K decay on stale prices** (not in SPEC)
- **R adaptation via Controller** (SPEC reserves R modification for system state dynamics)
- **Emergency health protection** (not in SPEC)
- **Vault failure non-fatal to epoch** (not in SPEC)
- **One-time vault latch** (deployment sequence not defined in SPEC)

SunPLS v1.4 also satisfies all invariants defined in the ProjectUSD R SPEC v2 with one noted architectural divergence: the Controller modifies R via `_stepR()` during Mode A epochs. This is a deliberate design decision — in the simplified four-contract architecture without a StabilityPool or SurplusBuffer, Controller-driven R adaptation is necessary to prevent equilibrium drift. The divergence is documented and defensible.

---

## What Comes Next

The system requires nothing. It will continue firing epochs, adjusting rates, and stepping R toward market reality for as long as anyone calls `triggerEpoch()` — and potentially longer if a keeper is eventually deployed.

The scientific question being answered in real time:

> Can a fully autonomous, immutable, governance-free monetary system with a proportional feedback controller maintain stability and correct peg deviations without human intervention?

After 20 epochs and several weeks of live operation: the early evidence is yes.

The track record builds one epoch at a time.

---

## References

- [SunPLS Architecture](./SUNPLS_ARCHITECTURE.md)
- [SunPLS Monetary Policy](./SUNPLS_MONETARY_POLICY.md)
- [SunPLS Protocol Parameters](./SUNPLS_PARAMETERS.md)
- [SunPLS Protocol Invariants](./SUNPLS_INVARIANTS.md)
- [SunPLS Oracle System](./SUNPLS_ORACLE.md)
- [SunPLS Security Model](./SUNPLS_SECURITY.md)
- [SunPLS Controller vs ProjectUSD SPEC](./SUNPLS_CONTROLLER_COMPARISON.md)
- ProjectUSD Controller SPEC v1 — Aqua75
- ProjectUSD R SPEC v2
- Study 19 — Analysis of Optimal Bounds of r
- Hayek, F.A. — *Denationalisation of Money* (1976)

---

*SunPLS is an experimental autonomous monetary protocol. This document is a research update, not financial advice. All contracts are immutable and unaudited. Participate at your own risk.*
