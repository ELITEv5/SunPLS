# sSunPLS — Auto-Compounding LP Vault

**Contract:** `0x3d2feBC4e6CFd3fe4Ae085B00434fb76eF54C0E9`
**Pair:** SunPLS / WPLS
**Network:** PulseChain
**Version:** sSunPLS v1.0
**Dev:** ELITE TEAM6

---

## What Is sSunPLS?

sSunPLS is an immutable, permissionless auto-compounding vault for SunPLS/WPLS liquidity providers on PulseChain.

When you provide liquidity to the SunPLS/WPLS pool on PulseX, you earn trading fees every time someone swaps through the pair. Normally, those fees sit in the pool as accumulated value and require you to manually remove and re-add liquidity to realize them as additional LP tokens. sSunPLS does this automatically, on behalf of all depositors, continuously.

Deposit your SunPLS/WPLS LP tokens into sSunPLS and receive **sSunPLS receipt shares** in return. Your shares stay constant, but the LP backing each share grows over time as trading fees are compounded back into the pool. When you withdraw, you receive more LP tokens than you put in — that difference is your yield.

---

## How It Works

### Deposit

Transfer your SunPLS/WPLS LP tokens to the vault. The vault mints sSunPLS shares proportional to your contribution relative to the total pool. On first deposit the ratio is 1:1. After compounding begins, new depositors receive slightly fewer shares per LP token — reflecting the appreciation already accrued by existing stakers.

### Compounding (Harvest)

Anyone can call the permissionless `harvest()` function once per hour. When called:

1. 1% of the vault's total LP holdings are sent to the PulseX pair contract and burned for underlying SunPLS and WPLS tokens
2. Those tokens are immediately re-added to the pool as liquidity via the PulseX router
3. Because the burned LP contained accumulated trading fees, the re-added liquidity mints slightly more LP than was burned
4. The net gain in LP tokens stays in the vault, raising the exchange rate for all sSunPLS holders

No fees are taken. No admin keys exist. The compounder benefits every staker equally and proportionally.

### Residual Handling

Due to pool ratio drift between harvest and re-add, the router may not be able to use 100% of both tokens when re-adding liquidity. Any leftover SunPLS or WPLS is tracked as a pending residual and swept back into the pool on the next harvest call. Each token side is handled independently — a zero balance on one side does not block the other from being swept.

### Withdraw

Burn your sSunPLS shares at any time to receive your proportional share of the vault's total LP holdings. Because the vault compounds continuously, the LP you receive on withdrawal will be greater than what you originally deposited — provided at least one successful harvest has occurred during your staking period.

There is no lockup, no withdrawal fee, and no penalty.

---

## Exchange Rate

The exchange rate expresses how many LP tokens back each sSunPLS share:

```
exchangeRate = totalLPHeld / totalsSunPLSSupply
```

At launch this is 1.0. It only ever increases — each successful harvest raises it slightly. The exchange rate is the single number that tells you whether the vault is working: a rising rate means fees are being compounded.

---

## LP Token Pricing

The SunPLS/WPLS LP token is priced by reading live reserves from the pair contract and applying the SunPLS oracle price:

```
SunPLS USD price  = (PLS per SunPLS from oracle) × (USD per PLS from oracle)
WPLS USD price    = USD per PLS from oracle
Pool USD value    = (SunPLS reserve × SunPLS USD price) + (WPLS reserve × WPLS USD price)
LP token price    = Pool USD value / LP total supply
```

Both sides of the pair are volatile assets. Neither is treated as a fixed $1 stablecoin. All USD values in the dashboard are derived from the SunPLS oracle at current market prices.

---

## Key Parameters

| Parameter | Value |
|---|---|
| Minimum deposit | 0.0001 LP |
| Harvest batch size | 1% of vault TVL per call |
| Minimum harvest interval | 1 hour |
| Slippage tolerance on re-add | 0.5% |
| Admin keys | None |
| Upgradeable | No |
| Governance | None |

---

## Security Properties

**Immutable.** The contract cannot be upgraded, paused, or modified after deployment. There are no admin functions, no owner, and no governance mechanism of any kind.

**Permissionless harvest.** Any address — including bots, keepers, or regular users — can call `harvest()`. No single party controls when compounding occurs.

**No fee extraction.** 100% of compounded fees accrue to sSunPLS holders. The contract takes nothing.

**Reentrancy protection.** All state-mutating functions are protected by OpenZeppelin's `ReentrancyGuard`.

**Emergency withdrawal.** A separate `emergencyWithdraw()` function allows users to exit proportionally at any time, bypassing all harvest logic, in the event the contract enters an unexpected state.

**CEI pattern.** Deposit follows Checks-Effects-Interactions ordering — share calculation occurs before the external LP transfer to prevent manipulation.

---

## Relationship to the SunPLS Ecosystem

sSunPLS is a companion contract to the SunPLS CDP system. SunPLS is a collateral-backed stablecoin minted against PLS on PulseChain. The SunPLS/WPLS liquidity pool is the primary venue for SunPLS price discovery and the source of the oracle price feeds that govern the CDP system's collateralization and liquidation logic.

Deep, stable liquidity in the SunPLS/WPLS pool directly strengthens the CDP system:

- Tighter spreads reduce oracle manipulation risk
- Greater depth absorbs liquidation pressure without price impact
- Higher trading volume generates more fees, which attract more LPs via sSunPLS compounding

sSunPLS creates a self-reinforcing loop: more LPs stake → deeper pool → healthier oracle → stronger CDP system → more SunPLS minted → more volume → more fees → higher sSunPLS APY → more LPs stake.

---

## Contract Addresses

| Contract | Address |
|---|---|
| sSunPLS Vault | `0x3d2feBC4e6CFd3fe4Ae085B00434fb76eF54C0E9` |
| SunPLS Token | `0x16cD95c278a7efbDA9ed6A17f9AcFcf1F6494D3F` |
| SunPLS/WPLS LP | `0xE4C6728b20595527CCB39fd4dB23Cf3b3464Cb55` |
| SunPLS Oracle | `0x7C853720c2D68Ba69FCcE08AC59E888E60Cb2Ea7` |
| SunPLS Controller | `0x59866633636B337203DDFc2C48163B32CB729b39` |
| SunPLS Vault (CDP) | `0x489C6999C39b2B34D1976A6daAc7E989F89679cE` |
| PulseX Router | `0x165C3410fC91EF562C50559f7d2289fEbed552d9` |

---

*Immutable. No admin keys. No governance. ELITE TEAM6.*
