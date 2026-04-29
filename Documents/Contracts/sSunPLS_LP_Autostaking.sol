// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * ╔══════════════════════════════════════════════════════════════════╗
 * ║           sSunPLS Auto-Compounding LP Vault V1.0                 ║
 * ║                                                                  ║
 * ║   Auto-compounds SunPLS/WPLS LP trading fees                     ║
 * ║   - Deposit LP → receive sSunPLS receipt tokens                  ║
 * ║   - Permissionless harvest compounds fees for all stakers        ║
 * ║   - sSunPLS appreciates vs LP over time                          ║
 * ║   - Withdraw anytime for your share of compounded LP             ║
 * ║                                                                  ║
 * ║   Pure auto-compounder, no external rewards needed               ║
 * ║   Immutable, no admin keys, no governance                        ║
 * ║                                                                  ║
 * ║   V1.0: Based on sSunDAI v1.1                                    ║
 * ║          Fixed single-sided residual sweep (both sides           ║
 * ║          swept independently, not gated on both > 0)             ║
 * ║                                                                  ║
 * ║   Pair:    SunPLS/WPLS                                           ║
 * ║   SunPLS:  0x04b37fa64a8d73a37D636608e5F6F8E5ce1541Aa            ║
 * ║   LP:      0xca46e01F4bF6938e8d8b8d22a570fFE96E9F0b19            ║
 * ║   Router:  0x165C3410fC91EF562C50559f7d2289fEbed552d9            ║
 * ║                                                                  ║
 * ║   Dev: ELITE TEAM6                                               ║
 * ╚══════════════════════════════════════════════════════════════════╝
 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IPulseXPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function mint(address to) external returns (uint256 liquidity);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

interface IPulseXRouter {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
}

contract sSunPLS is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ═══════════════════════════ IMMUTABLES ═══════════════════════════
    IPulseXPair  public immutable lpToken;   // SunPLS/WPLS LP token
    IERC20       public immutable token0;    // First token in pair  (as returned by pair)
    IERC20       public immutable token1;    // Second token in pair (as returned by pair)
    IPulseXRouter public immutable router;   // PulseX router for re-adding liquidity

    string public constant VERSION = "sSunPLS_v1.0_AutoCompounder";

    // ═══════════════════════════ CONSTANTS ═══════════════════════════
    uint256 public constant MIN_DEPOSIT          = 1e14;    // 0.0001 LP minimum — dust protection
    uint256 public constant HARVEST_BATCH_BPS    = 100;     // Harvest 1% of pool per call
    uint256 public constant MIN_HARVEST_INTERVAL = 1 hours; // Rate-limit harvests
    uint256 public constant SLIPPAGE_BPS         = 50;      // 0.5% max slippage on re-add

    // ═══════════════════════════ STATE ═══════════════════════════════
    uint256 public lastHarvestTime;
    uint256 public totalHarvests;
    uint256 public totalFeesCompounded;  // In LP token units

    // Residual tokens from ratio mismatch on addLiquidity — swept on next harvest.
    // V1.0 fix: each side is tracked and swept independently (no dual-nonzero gate).
    uint256 public pendingToken0;
    uint256 public pendingToken1;

    // ═══════════════════════════ EVENTS ══════════════════════════════
    event Deposited(address indexed user, uint256 lpAmount, uint256 sharesReceived);
    event Withdrawn(address indexed user, uint256 sharesRedeemed, uint256 lpAmount);
    event Harvested(
        address indexed caller,
        uint256 lpBurned,
        uint256 lpMinted,
        uint256 netGain,
        uint256 residual0,
        uint256 residual1
    );
    event EmergencyWithdraw(address indexed user, uint256 lpAmount);
    event ResidualSwept(uint256 token0Swept, uint256 token1Swept, uint256 lpMinted);

    // ═══════════════════════════ CONSTRUCTOR ═════════════════════════
    constructor(
        address _lpToken,   // 0xE4C6728b20595527CCB39fd4dB23Cf3b3464Cb55
        address _router     // 0x165C3410fC91EF562C50559f7d2289fEbed552d9
    ) ERC20("Staked SunPLS LP", "sSunPLS") {
        require(_lpToken != address(0), "Zero LP");
        require(_router  != address(0), "Zero router");

        lpToken = IPulseXPair(_lpToken);
        router  = IPulseXRouter(_router);

        // Resolve pair tokens from the LP contract itself — order is canonical
        token0 = IERC20(lpToken.token0());
        token1 = IERC20(lpToken.token1());

        // Approve router once for all future compounding
        token0.approve(_router, type(uint256).max);
        token1.approve(_router, type(uint256).max);

        lastHarvestTime = block.timestamp;
    }

    // ═══════════════════════════ USER ACTIONS ════════════════════════

    /**
     * @notice Deposit LP tokens and receive sSunPLS shares.
     * @param  lpAmount  Amount of SunPLS/WPLS LP tokens to deposit.
     * @return shares    sSunPLS shares minted to caller.
     */
    function deposit(uint256 lpAmount) external nonReentrant returns (uint256 shares) {
        require(lpAmount >= MIN_DEPOSIT, "Amount too small");

        uint256 totalLP     = lpToken.balanceOf(address(this));
        uint256 totalShares = totalSupply();

        if (totalShares == 0 || totalLP == 0) {
            shares = lpAmount; // First deposit: 1:1 bootstrap
        } else {
            shares = (lpAmount * totalShares) / totalLP;
        }

        require(shares > 0, "Zero shares");

        IERC20(address(lpToken)).safeTransferFrom(msg.sender, address(this), lpAmount);
        _mint(msg.sender, shares);

        emit Deposited(msg.sender, lpAmount, shares);
    }

    /**
     * @notice Withdraw LP tokens by burning a specified amount of sSunPLS shares.
     * @param  shares   Amount of sSunPLS to burn.
     * @return lpAmount LP returned to caller.
     */
    function withdraw(uint256 shares) external nonReentrant returns (uint256 lpAmount) {
        require(shares > 0,                          "Zero shares");
        require(balanceOf(msg.sender) >= shares,     "Insufficient balance");

        uint256 totalLP     = lpToken.balanceOf(address(this));
        uint256 totalShares = totalSupply();

        lpAmount = (shares * totalLP) / totalShares;
        require(lpAmount > 0, "Zero LP");

        _burn(msg.sender, shares);
        IERC20(address(lpToken)).safeTransfer(msg.sender, lpAmount);

        emit Withdrawn(msg.sender, shares, lpAmount);
    }

    /**
     * @notice Convenience: withdraw entire position in one call.
     * @return lpAmount LP returned to caller.
     */
    function withdrawAll() external nonReentrant returns (uint256 lpAmount) {
        uint256 shares = balanceOf(msg.sender);
        require(shares > 0, "No shares");

        uint256 totalLP     = lpToken.balanceOf(address(this));
        uint256 totalShares = totalSupply();

        lpAmount = (shares * totalLP) / totalShares;
        require(lpAmount > 0, "Zero LP");

        _burn(msg.sender, shares);
        IERC20(address(lpToken)).safeTransfer(msg.sender, lpAmount);

        emit Withdrawn(msg.sender, shares, lpAmount);
    }

    // ═══════════════════════════ HARVEST (PERMISSIONLESS) ════════════

    /**
     * @notice Harvest accumulated trading fees and compound them back into LP.
     * @dev    Permissionless — any EOA or contract may call.
     *         Removes 1% of pool LP, re-adds underlying tokens, net LP gain
     *         stays in the vault and raises the sSunPLS exchange rate.
     *
     *         Residual tokens (from pool ratio drift on re-add) are stored and
     *         swept back on the next harvest call.  Each token side is swept
     *         independently — no dual-nonzero gate (V1.0 fix vs sSunDAI v1.1).
     *
     * @return netGain  Additional LP units compounded this call.
     */
    function harvest() external nonReentrant returns (uint256 netGain) {
        require(
            block.timestamp >= lastHarvestTime + MIN_HARVEST_INTERVAL,
            "Too soon"
        );

        // Step 0 — Sweep any residuals left from the previous harvest
        _sweepResiduals();

        // Step 1 — Determine harvest slice (1% of current TVL)
        uint256 harvestAmount = _calcHarvestAmount();

        // Step 2 — Burn LP, collect underlying, re-add liquidity
        uint256 lpMinted = _burnAndReadd(harvestAmount);

        // Step 3 — Net gain is what the compounder extracted from fees
        netGain = lpMinted > harvestAmount ? lpMinted - harvestAmount : 0;

        lastHarvestTime      = block.timestamp;
        totalHarvests       += 1;
        totalFeesCompounded += netGain;

        emit Harvested(
            msg.sender,
            harvestAmount,
            lpMinted,
            netGain,
            pendingToken0,
            pendingToken1
        );
    }

    // ─────────────────────── internal harvest helpers ────────────────

    /**
     * @dev Sweep residual tokens from prior harvest back into LP.
     *      Each side swept independently — a zero balance on one side
     *      does not block sweeping the other.
     */
    function _sweepResiduals() internal {
        uint256 s0 = pendingToken0;
        uint256 s1 = pendingToken1;

        // Nothing to do
        if (s0 == 0 && s1 == 0) return;

        pendingToken0 = 0;
        pendingToken1 = 0;

        // If only one side has a residual we still attempt addLiquidity;
        // the router will accept the available token up to pool ratio and
        // any unused amount is returned — those get re-stored as pending.
        uint256 in0 = s0 > 0 ? s0 : 0;
        uint256 in1 = s1 > 0 ? s1 : 0;

        // Only call router when at least one side is non-zero
        if (in0 == 0 && in1 == 0) return;

        (uint256 used0, uint256 used1, uint256 sweptLP) = router.addLiquidity(
            address(token0),
            address(token1),
            in0,
            in1,
            (in0 * (10000 - SLIPPAGE_BPS)) / 10000,
            (in1 * (10000 - SLIPPAGE_BPS)) / 10000,
            address(this),
            block.timestamp + 300
        );

        // Re-store any amount the router couldn't use
        uint256 r0 = in0 - used0;
        uint256 r1 = in1 - used1;
        if (r0 > 0) pendingToken0 = r0;
        if (r1 > 0) pendingToken1 = r1;

        if (sweptLP > 0) emit ResidualSwept(s0, s1, sweptLP);
    }

    /**
     * @dev Returns the LP amount to harvest this call (1% of vault TVL).
     *      Reverts if TVL is too small to produce a meaningful harvest.
     */
    function _calcHarvestAmount() internal view returns (uint256 harvestAmount) {
        uint256 totalLP = IERC20(address(lpToken)).balanceOf(address(this));
        require(totalLP >= 1e18, "TVL too small to harvest");
        harvestAmount = (totalLP * HARVEST_BATCH_BPS) / 10000;
        require(harvestAmount >= MIN_DEPOSIT, "Harvest amount too small");
    }

    /**
     * @dev Burn `harvestAmount` LP, re-add underlying tokens as liquidity.
     *      Stores per-token residuals from ratio drift for next sweep.
     * @return lpMinted  New LP tokens received from addLiquidity.
     */
    function _burnAndReadd(uint256 harvestAmount) internal returns (uint256 lpMinted) {
        // Send LP to pair contract then call burn — standard PulseX flow
        IERC20(address(lpToken)).safeTransfer(address(lpToken), harvestAmount);
        (uint256 amount0, uint256 amount1) = lpToken.burn(address(this));
        require(amount0 > 0 && amount1 > 0, "Burn returned zero");

        // Re-add underlying tokens; router returns actual amounts used
        (uint256 used0, uint256 used1, uint256 minted) = router.addLiquidity(
            address(token0),
            address(token1),
            amount0,
            amount1,
            (amount0 * (10000 - SLIPPAGE_BPS)) / 10000,
            (amount1 * (10000 - SLIPPAGE_BPS)) / 10000,
            address(this),
            block.timestamp + 300
        );

        // Accumulate leftovers — swept on next harvest
        uint256 r0 = amount0 - used0;
        uint256 r1 = amount1 - used1;
        if (r0 > 0) pendingToken0 += r0;
        if (r1 > 0) pendingToken1 += r1;

        return minted;
    }

    // ═══════════════════════════ EMERGENCY ═══════════════════════════

    /**
     * @notice Emergency proportional withdrawal — bypasses all harvest logic.
     * @dev    Use if contract enters an unexpected state. Share math is identical
     *         to normal withdraw — no penalty, no lockup.
     */
    function emergencyWithdraw() external nonReentrant {
        uint256 shares = balanceOf(msg.sender);
        require(shares > 0, "No shares");

        uint256 totalLP     = lpToken.balanceOf(address(this));
        uint256 totalShares = totalSupply();
        uint256 lpAmount    = (shares * totalLP) / totalShares;

        _burn(msg.sender, shares);
        IERC20(address(lpToken)).safeTransfer(msg.sender, lpAmount);

        emit EmergencyWithdraw(msg.sender, lpAmount);
    }

    // ═══════════════════════════ VIEW FUNCTIONS ═══════════════════════

    /// @notice LP tokens backing each sSunPLS share (18-decimal fixed point).
    function exchangeRate() external view returns (uint256 rate) {
        uint256 totalShares = totalSupply();
        if (totalShares == 0) return 1e18;
        rate = (lpToken.balanceOf(address(this)) * 1e18) / totalShares;
    }

    /// @notice LP amount redeemable for `shares` sSunPLS.
    function previewWithdraw(uint256 shares) external view returns (uint256 lpAmount) {
        uint256 totalShares = totalSupply();
        if (totalShares == 0) return 0;
        lpAmount = (shares * lpToken.balanceOf(address(this))) / totalShares;
    }

    /// @notice sSunPLS shares that would be minted for `lpAmount` deposited now.
    function previewDeposit(uint256 lpAmount) external view returns (uint256 shares) {
        uint256 totalLP     = lpToken.balanceOf(address(this));
        uint256 totalShares = totalSupply();
        if (totalShares == 0 || totalLP == 0) {
            shares = lpAmount;
        } else {
            shares = (lpAmount * totalShares) / totalLP;
        }
    }

    /// @notice Whether harvest() can be called right now.
    function canHarvest() external view returns (bool ready, uint256 timeUntilReady) {
        if (block.timestamp >= lastHarvestTime + MIN_HARVEST_INTERVAL) {
            return (true, 0);
        }
        timeUntilReady = (lastHarvestTime + MIN_HARVEST_INTERVAL) - block.timestamp;
        return (false, timeUntilReady);
    }

    /// @notice Per-user summary: shares held, current LP value, appreciation in bps.
    function userInfo(address user) external view returns (
        uint256 shares,
        uint256 lpValue,
        uint256 appreciationBps
    ) {
        shares = balanceOf(user);
        uint256 totalShares = totalSupply();
        if (totalShares == 0 || shares == 0) return (shares, 0, 0);

        uint256 totalLP = lpToken.balanceOf(address(this));
        lpValue = (shares * totalLP) / totalShares;

        if (lpValue > shares) {
            appreciationBps = ((lpValue - shares) * 10000) / shares;
        }
    }

    /// @notice Full vault statistics for dashboards.
    function vaultStats() external view returns (
        uint256 totalLPHeld,
        uint256 totalSharesIssued,
        uint256 currentExchangeRate,
        uint256 harvestCount,
        uint256 feesCompounded,
        uint256 timeSinceLastHarvest,
        uint256 pendingResidual0,
        uint256 pendingResidual1
    ) {
        totalLPHeld       = lpToken.balanceOf(address(this));
        totalSharesIssued = totalSupply();
        currentExchangeRate = totalSharesIssued == 0
            ? 1e18
            : (totalLPHeld * 1e18) / totalSharesIssued;
        harvestCount          = totalHarvests;
        feesCompounded        = totalFeesCompounded;
        timeSinceLastHarvest  = block.timestamp - lastHarvestTime;
        pendingResidual0      = pendingToken0;
        pendingResidual1      = pendingToken1;
    }

    /// @notice Max LP withdrawable by `user` at current exchange rate.
    function maxWithdraw(address user) external view returns (uint256 maxLP) {
        uint256 shares = balanceOf(user);
        if (shares == 0) return 0;
        uint256 totalShares = totalSupply();
        maxLP = (shares * lpToken.balanceOf(address(this))) / totalShares;
    }

    /// @notice All-in-one position data for frontend display.
    function positionInfo(address user) external view returns (
        uint256 sharesOwned,
        uint256 lpValue,
        uint256 appreciationBps,
        uint256 appreciationPercent,
        uint256 depositedLP,
        uint256 earnedLP
    ) {
        sharesOwned = balanceOf(user);
        if (sharesOwned == 0) return (0, 0, 0, 0, 0, 0);

        uint256 totalShares = totalSupply();
        uint256 totalLP     = lpToken.balanceOf(address(this));

        lpValue     = (sharesOwned * totalLP) / totalShares;
        depositedLP = sharesOwned; // Approximation: assumes 1:1 at time of deposit

        if (lpValue > depositedLP) {
            earnedLP          = lpValue - depositedLP;
            appreciationBps   = (earnedLP * 10000) / depositedLP;
            appreciationPercent = appreciationBps / 100;
        }
    }

    /// @notice Returns true if `user` holds any sSunPLS shares.
    function hasPosition(address user) external view returns (bool) {
        return balanceOf(user) > 0;
    }

    /// @notice LP token address.
    function getLPToken() external view returns (address) {
        return address(lpToken);
    }

    /// @notice Underlying pair token addresses (canonical order from pair contract).
    function getPairTokens() external view returns (address token0Address, address token1Address) {
        return (address(token0), address(token1));
    }
}


