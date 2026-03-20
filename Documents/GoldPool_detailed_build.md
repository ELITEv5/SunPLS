# PBTCG-Backed Stable Asset System — Build Plan
*A ProjectUSD-spec compliant CDP using PBTCG as collateral, built parallel to SunPLS*

---

## What We Are Building

A new ProjectUSD-compliant CDP system where:

- **Collateral:** PBTCG (PulseBitcoin Gold)
- **Stable asset:** New ProjectUSD-spec token (working name: SunGold — rename before launch)
- **Oracle:** PBTCG NAV feed replacing the PLS price feed used in SunPLS
- **Liquidation:** Redistribution to stability pool, replacing the market liquidation used in SunPLS
- **Architecture:** Parallel deployment — completely independent of SunPLS v1.4, no shared contracts

SunPLS is the live reference implementation. It proves the ProjectUSD spec works in production. This system extends the spec to a new collateral type with fundamentally different stress behavior.

---

## What Carries Over From SunPLS

Before mapping what is new, be precise about what carries over directly from the live SunPLS deployment.

**Controller rate logic.** The stability rate mechanism, epoch triggering, and R value derivation transfer intact. The ProjectUSD math does not care what the collateral asset is. `triggerEpoch()`, the ALPHA damping, the spread and deadband logic — all reused without modification.

**Token contract.** SunGold is the same ERC20 pattern as the live SunPLS token at `0x04b37fa64a8d73a37D636608e5F6F8E5ce1541Aa`, with a new name and the new vault as the authorized minter.

**Router pattern.** Same user-facing entry point structure as the live SunPLS Router at `0x165C3410fC91EF562C50559f7d2289fEbed552d9`.

**Frontend architecture.** Same public RPC pattern reading from `https://rpc.pulsechain.com`, same ethers v6 approach, same chunked event scanning from deploy block.

**Deployment pattern.** Same constructor argument structure as SunPLS v1.4. Same circular dependency resolution via `setVault()` dual latch proven in the live deployment.

**Invariant framework.** The nine SunPLS invariants carry forward. New invariants specific to PBTCG collateral and redistribution are added on top.

This is approximately 70% of the total codebase, confirmed by ABI analysis of both live contracts. New logic is concentrated in exactly three places: the NAV oracle, the redistribution mechanism replacing liquidation, and the stability pool contract. Everything else is a rename and redeploy against the live SunPLS contracts as the proven template.

**ABI-confirmed functions that carry over from the live vault unchanged:**

```
deposit(uint256)            mint(uint256)               repay(uint256)
repayAndWithdrawAll()       vaultInfo(address)          maxMint(address)
systemHealth()              totalCollateral()            totalDebt()
currentRate()               updateRate(int256)           getVaultCount()
getVaultOwner(uint256)      isVaultOwner(address)        vaults(address)
vaultOwners(uint256)        badDebt()                    canRedeem(address)
redeem(uint256, address)    redemptionPreview(...)        repayToHealth(address)
```

**ABI-confirmed functions removed entirely — PLS-native, no ERC20 equivalent:**

```
depositPLS()                depositAndAutoMintPLS()      withdrawPLS(uint256)
withdrawWPLS(uint256)       wpls()                       receive() payable fallback
```

**ABI-confirmed functions replaced:**

```
liquidate(address, uint256)     →  redistribute(address)
canLiquidate(address)           →  canRedistribute(address)
liquidationInfo(address)        →  redistributionInfo(address)
```

**ABI-confirmed constants removed — liquidator incentive model eliminated:**

```
AUCTION_TIME                MAX_BONUS_BPS               MIN_BONUS_BPS
MIN_LIQUIDATION_BPS         LIQUIDATION_COOLDOWN → replaced with REDISTRIBUTION_COOLDOWN
```

**Vault struct field rename confirmed from live ABI:**

```
lastLiquidationTime  →  lastRedistributionTime
```

All other struct fields — `collateral`, `debt`, `lastDepositTime`, `lastDebtAccrual`, `undercollateralizedSince`, `lastRedemptionTime` — carry over with no changes.

---

## What Changes

### 1. The Oracle — Biggest Architectural Departure

The live SunPLS oracle at `0xc8B4d7d885D41826CB46376676638449332aeA87` reads PLS price from five PulseX pairs and returns a median. The ProjectUSD spec requires a reliable price feed for whatever the collateral asset is. For PBTCG that feed requires two components combined through the GoldPool NAV formula.

**Component A — PBTC/USD price**

Same multi-pair median pattern as the live SunPLS oracle. PBTC trades on PulseX so the same oracle architecture applies directly. Candidate pairs:

- PBTC/PLS converted via PLS/USD
- PBTC/DAI if liquid
- PBTC/USDC if liquid

Fork the live SunPLS oracle contract, swap the pair addresses, redeploy. The asymmetric confirmation periods from SunPLS — 4-hour drop confirmation, 1-hour rise confirmation — carry over unchanged into this oracle. Same stepping mechanism, same manipulation resistance.

**Component B — Gold/USD price**

New dependency with no equivalent in the live SunPLS system. Options in order of implementation preference:

- **PulseX PAXG pairs** — same median pattern as SunPLS oracle, fully on-chain, cleanest long-term implementation. Requires sufficient PAXG liquidity on PulseChain.
- **Governance-updated value** — multisig updates the gold price parameter on a fixed schedule. Simpler, introduces centralization risk, acceptable for v1.0 while PAXG liquidity develops.
- **Tellor oracle** — decentralized feed available on PulseChain with gold price support. Adds external dependency.

For v1.0, the governance-updated gold price is the pragmatic choice. Ship faster, reduce complexity, replace with PulseX PAXG median in v2 once the system has traction. Document this explicitly as a planned upgrade rather than a permanent design.

**NAV Calculation in the Oracle Contract:**

```solidity
function getPrice() external view returns (uint256) {
    uint256 pbtcPrice = pbtcOracle.getPrice();
    uint256 goldPrice = goldPriceSource.getPrice();

    // Call GoldPool vault view function
    uint256 rawNAV = goldPoolVault.getNAV(pbtcPrice, goldPrice);

    // Apply conservative haircut — oracle returns adjusted NAV
    return rawNAV * NAV_HAIRCUT / 100; // 70% of NAV
}
```

The oracle returns the haircut NAV directly. The vault applies its standard ProjectUSD CR logic on top. The haircut and the CR are multiplicative safety layers — model both together before setting final values to avoid over-penalizing capital efficiency.

**TWAP requirement:**

The live SunPLS oracle uses spot pricing against a liquid PLS market. PBTCG NAV moves more slowly and is composed of two inputs, each with its own manipulation surface. A 24-hour TWAP is required.

```solidity
struct TWAPObservation {
    uint256 timestamp;
    uint256 navValue;
}

TWAPObservation[24] public observations; // hourly snapshots
uint256 public twapNAV;

function updateTWAP() external {
    // Permissionless — callable by anyone once per hour
    // Pushes new observation, recalculates rolling 24hr average
    // Optional: small gas rebate for callers to ensure reliable updates
}
```

An attacker must sustain oracle manipulation for 24 hours to move the TWAP meaningfully. Combined with the 70% NAV haircut and the CR buffer this makes the oracle attack surface significantly more expensive than exploiting it is worth.

---

### 2. The Vault — Collateral Handling and Liquidation

The vault changes in two specific places relative to the live SunPLS vault at `0x6521899F840847de88E87A121447FfB7b5aF9aF0`. Everything else in the ProjectUSD vault logic carries over.

**Collateral type:**

Instead of accepting native PLS, the vault accepts PBTCG ERC20 transfers. The deposit function calls `IERC20(pbtcg).transferFrom(msg.sender, address(this), amount)`. Per-position collateral accounting, CR enforcement, minimum deposit logic — all identical to the live SunPLS vault. Only the asset type changes.

**Liquidation → Redistribution:**

This is the meaningful departure from the live SunPLS liquidation path. The ProjectUSD spec as implemented in SunPLS sells collateral to cover bad debt. For PBTCG that mechanism is replaced entirely:

```solidity
function redistribute(address position) external {
    require(isUndercollateralized(position), "Position healthy");

    uint256 pbtcgAmount = positions[position].collateral;
    uint256 debtAmount = positions[position].debt;

    // Transfer PBTCG to stability pool — no market sell ever occurs
    IERC20(pbtcg).transfer(stabilityPool, pbtcgAmount);

    // Absorb bad debt via stability pool SunGold balance
    IStabilityPool(stabilityPool).absorbDebt(debtAmount);

    // Clear the position
    delete positions[position];

    emit Redistribution(position, pbtcgAmount, debtAmount);
}
```

No price oracle interaction at redistribution time. No market sell. No reflexive price impact on PBTCG. The stability pool receives PBTCG and covers the debt from its SunGold balance. This is the property that makes the system structurally different from SunPLS and from every standard ProjectUSD implementation — the collateral base cannot generate sell pressure on itself.

**CR thresholds:**

SunPLS v1.4 uses 130% `REDEMPTION_RATIO` after the v1.3 → v1.4 update. For PBTCG collateral, with the 70% NAV haircut already applied in the oracle, 130–140% minimum CR is defensible. Model the combined effect of haircut plus CR across multiple price scenarios before committing final values to the immutable contract.

---

### 3. The Stability Pool — New Contract

SunPLS does not have a stability pool. The live SunPLS system sends liquidation proceeds directly to market. This is a new contract with no equivalent in the existing codebase. It is the most architecturally novel component of this system relative to the live ProjectUSD implementation in SunPLS.

```solidity
contract SunGoldStabilityPool {

    // SunGold deposited by stability providers
    mapping(address => uint256) public deposits;
    uint256 public totalDeposits;

    // PBTCG accumulated from redistribution events
    uint256 public accumulatedPBTCG;
    mapping(address => uint256) public pbtcgClaims;

    function provideStability(uint256 sunGoldAmount) external {
        // Deposit SunGold, record pro-rata share
    }

    function withdrawStability(uint256 sunGoldAmount) external {
        // Withdraw SunGold plus accrued PBTCG share
    }

    function absorbDebt(uint256 debtAmount) external onlyVault {
        // Burns SunGold from pool to cover bad debt
        // Records pro-rata PBTCG distribution to depositors
    }

    function claimPBTCG() external {
        // Stability providers claim accumulated PBTCG
    }
}
```

Stability providers earn PBTCG over time as redistribution events occur. This creates aligned incentives: participants who believe in GoldPool long-term provide stability to the ProjectUSD-spec system and accumulate more PBTCG exposure as a direct reward. The stability pool PBTCG accumulation rate is also a public on-chain signal of system stress — a rapidly filling pool is an early warning indicator visible to anyone reading contract state.

---

## Stable Asset — Confirmed: New Token Required

**ABI analysis of the live SunPLS token at `0x04b37fa64a8d73a37D636608e5F6F8E5ce1541Aa` closes this question definitively.**

The token contract exposes:

```
setVault(address _vault)    — one-time latch, no access control beyond first call
vaultSet()                  — returns bool, flips permanently to true on first call
vault()                     — returns single vault address
mint(address, uint256)      — callable only by the single authorized vault
burn(address, uint256)      — callable only by the single authorized vault
```

There is no `addMinter()`, no minter array, no multi-vault support. The `setVault()` / `vaultSet` pattern is a one-time latch — once called it permanently locks to a single vault address. The live SunPLS token cannot authorize a second minter under any circumstances.

**SunGold is a new, separate ProjectUSD-spec token.** It uses the identical contract pattern as the live SunPLS token — same `setVault()` latch, same `mint()` / `burn()` authorization model, same ERC20 base — deployed fresh with the new PBTCG vault as its sole authorized minter. No further decision required here.

---

## Contract Deployment Order

Same circular dependency structure as the live SunPLS v1.4 deployment. Same dual latch resolution.

```
1. Deploy SunGold Token
   Constructor: name, symbol, decimals
   No vault address yet — same pattern as live SunPLS token deployment
   Identical contract to live SunPLS token, new name, new deployment

2. Deploy PBTCG NAV Oracle
   Constructor: pbtcOracle address, goldPriceSource, goldPoolVault address
   *** Hard dependency: GoldPool vault must be deployed before this step ***

3. Deploy Stability Pool
   Constructor: sunGoldToken address, pbtcg token address

4. Deploy Vault
   Constructor: sunGoldToken, pbtcgOracle, stabilityPool, pbtcg
   Calls sunGoldToken.setVault(address(this))  ← same dual latch as SunPLS

5. Deploy Controller
   Constructor: vault address, sunGoldToken
   Calls vault.setController(address(this))    ← same dual latch as SunPLS

6. Deploy Router
   Constructor: vault, controller, sunGoldToken, pbtcg

7. Authorize Stability Pool on Vault
   vault.setStabilityPool(stabilityPool)

8. Seed Stability Pool
   Initial SunGold deposit to ensure redistribution capability exists at launch
   System must not open for deposits with an empty stability pool
```

**The hard dependency:** GoldPool vault must be deployed and audited before step 2. The NAV oracle needs the GoldPool vault address to call `getNAV()`. This system cannot reach mainnet before GoldPool does. Plan the timeline accordingly.

---

## New Invariants

The nine SunPLS invariants carry forward into this system. The following are added on top, specific to PBTCG collateral and the redistribution mechanism:

| # | Invariant | Enforcement |
|---|---|---|
| 10 | PBTCG collateral only exits vault via redistribution to stability pool | No withdrawal function, hardcoded recipient |
| 11 | Redistribution recipient is stability pool address only | Immutable address set at deployment |
| 12 | Stability pool PBTCG only claimable pro-rata by depositors | Accounting enforced in stability pool contract |
| 13 | NAV oracle uses 24hr TWAP not spot price | TWAP accumulator enforced in oracle contract |
| 14 | SunGold minting only via authorized vault | Token contract minter authorization |
| 15 | Bound PBTC in GoldPool never decreases | Inherited from GoldPool invariant set |

---

## Frontend — Three Pages

Architecture identical to the live SunPLS frontend. Static HTML reading public RPC at `https://rpc.pulsechain.com`. Ethers v6. No backend. No server. No failure point beyond RPC availability.

**`index.html` — Main dashboard**

Pre-connection panel:
- PBTCG NAV live from oracle TWAP
- SunGold total supply
- System CR — total collateral value divided by total debt
- Stability pool SunGold balance
- Total PBTCG locked as collateral
- Controller panel state — same display pattern as live SunPLS index

Connected wallet panel:
- User PBTCG collateral balance
- Outstanding SunGold debt
- Current CR with color indicator — green above 150%, yellow 120–150%, red below 120%
- Borrow ceiling remaining
- One-click deposit, borrow, repay flows

**`stability.html` — Stability pool interface**

- Current pool SunGold balance
- User deposit amount and percentage share
- Accrued PBTCG claimable by connected wallet
- Redistribution event history with amounts and timestamps
- Estimated PBTCG yield rate based on recent redistribution frequency

**`redistributions.html` — Event history**

Same pattern as `liquidations.html` in the live SunPLS frontend. Chunked 10,000-block event scanning starting from vault deploy block. Displays all redistribution events: position address, PBTCG amount redistributed, SunGold debt absorbed, block timestamp.

---

## Build Sequence

```
Week 1–2   Oracle development
           Fork live SunPLS oracle at 0xc8B4d7d885D41826CB46376676638449332aeA87
           Replace PLS pairs with PBTC pairs
           Add gold price source (governance-updated v1)
           Add 24hr TWAP accumulator
           Test getNAV() calls against GoldPool on testnet

Week 3–4   Vault modifications
           Fork live SunPLS vault at 0x6521899F840847de88E87A121447FfB7b5aF9aF0
           Replace PLS collateral handling with PBTCG ERC20 pattern
           Replace liquidation path with redistribution
           Adjust CR thresholds — model against haircut before committing
           Unit test full position lifecycle

Week 5     Stability pool
           New contract — no analog in live SunPLS system
           Test redistribution absorption under various pool sizes
           Test pro-rata PBTCG distribution accounting
           Test deposit and withdrawal under active redistribution

Week 6     Integration testing
           Full flow: deposit PBTCG → mint SunGold → repay → withdraw
           Redistribution scenario: undercollateralized position → pool absorption
           Oracle manipulation resistance: TWAP boundary conditions
           Edge cases: empty stability pool, max borrow, dust positions

Week 7–8   Audit
           Focus specifically on:
             redistribution logic and stability pool accounting
             TWAP oracle implementation
             minter authorization pattern
             interaction between vault and stability pool under stress

Week 9     Testnet deployment
           Full deployment sequence per order above
           30-day monitoring period before mainnet consideration
           Dashboard live on testnet pointing at testnet contracts

Week 10+   Mainnet — hard gated by GoldPool deployment
           GoldPool vault must be live and audited before this system deploys
```

---

## The Full Value Loop

Once both GoldPool and this system are live on mainnet:

```
PBTC holder deposits into GoldPool
  → receives PBTCG (ownership claim on permanently locked vault)
  → deposits PBTCG into this vault as collateral
  → borrows SunGold stable asset against PBTCG NAV floor
  → deploys SunGold into DeFi (LP, yield, spending, ProjectUSD ecosystem)
  → repays SunGold debt over time
  → reclaims PBTCG collateral
  → GoldPool vault continues growing via continuous transformation
  → PBTCG NAV floor rises
  → borrow ceiling increases on next deposit
```

At no point in this loop is PBTC sold. At no point does a price drop trigger a forced sell. The only exit from the collateral layer is voluntary repayment or redistribution — and redistribution moves PBTCG to the stability pool, not to market.

This is the property that makes this system structurally distinct from the live SunPLS system and from every standard ProjectUSD implementation. SunPLS proves the spec works. This system extends it to a collateral type that cannot generate reflexive sell pressure on itself. Both systems are stronger for existing simultaneously.

---

## Relationship to Live SunPLS System

| Property | SunPLS (live, PLS collateral) | This system (PBTCG collateral) |
|---|---|---|
| ProjectUSD spec compliant | Yes | Yes |
| Collateral asset | PLS — native, liquid | PBTCG — ERC20, GoldPool-issued |
| Oracle | PLS/USD 5-pair median | PBTCG NAV TWAP — two-input |
| Liquidation mechanism | Market sell | Redistribution to stability pool |
| Death spiral possible | Mitigated, not eliminated | Structurally impossible |
| Capital efficiency | Moderate | Lower — NAV haircut required |
| Collateral base | All PLS holders | GoldPool depositors |
| Bootstrap difficulty | Proven | Depends on GoldPool adoption |
| Stress behavior | Rate adjusts, liquidations possible | Redistribution only, no market impact |
| Collateral improves over time | No | Yes — vault accumulation grows NAV floor |

These systems are complementary. SunPLS handles high-volume capital-efficient stable asset issuance against the broadest possible PulseChain collateral base. This system provides a structurally indestructible stable asset layer backed by permanently locked value. Two implementations of the same ProjectUSD spec, different risk profiles, one ecosystem.

---

*Document version 1.1 — PBTCG CDP build plan, SunPLS as live reference, ProjectUSD as target spec. Updated with ABI-confirmed function diff (token + vault) and stable asset decision resolved.*
