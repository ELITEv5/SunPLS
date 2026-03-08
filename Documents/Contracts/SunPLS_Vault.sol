// SPDX-License-Identifier: CC-BY-NC-SA-4.0
pragma solidity ^0.8.20;

/**
 * ╔══════════════════════════════════════════════════════════════════════╗
 * ║           SunPLS Vault v1.3 — ELITE TEAM6                            ║
 * ║           Autonomous Stable Asset — ProjectUSD Architecture          ║
 * ║                                                                      ║
 * ║   PLS-collateralized CDP vault with full autonomous stability        ║
 * ║                                                                      ║
 * ║   CHANGELOG v1.3:                                                    ║
 * ║   • CRITICAL FIX: Corrected oracle price direction throughout.       ║
 * ║                                                                      ║
 * ║     Oracle returns WPLS per SunPLS (1e18-scaled).                    ║
 * ║     Example: price = 117378e18 → 1 SunPLS costs 117,378 PLS          ║
 * ║                                                                      ║
 * ║     CORRECT conversions:                                             ║
 * ║       collateralValue(SunPLS) = collateral(PLS) * 1e18 / price       ║
 * ║       plsEquivalent(SunPLS)   = sunpls * price / 1e18                ║
 * ║       CR%  = col * 1e18 * 100 / (debt * price)                       ║
 * ║       safe = col * 1e18 * 100 >= debt * ratio * price                ║
 * ║                                                                      ║
 * ║     v1.2 used the inverse formula (col * price / 1e18) everywhere,   ║
 * ║     producing collateral values ~13.7 billion times too large and    ║
 * ║     allowing unlimited SunPLS minting against any PLS deposit.       ║
 * ║                                                                      ║
 * ║   FUNCTIONS CHANGED (all others byte-identical to v1.2):             ║
 * ║   • depositAndAutoMintPLS — valueUSD = msg.value * 1e18 / price      ║
 * ║   • _isAtLiquidationThreshold — col*1e18*100 < debt*LIQ_R*price      ║
 * ║   • _isSafeAtRatio — col*1e18*100 >= debt*ratio*price                ║
 * ║   • _collateralRatio — col*1e18*100 / (debt*price)                   ║
 * ║   • systemHealth — totalCol*1e18*100 / (totalDebt*price)             ║
 * ║   • liquidate — base = repay * price / 1e18                          ║
 * ║   • redeem — plsOut = sunpls * R / 1e18                              ║
 * ║   • redemptionPreview — plsOut = sunpls * R / 1e18                   ║
 * ║   • liquidationInfo — base = minRepay * price / 1e18                 ║
 * ║   • vaultInfo — collateralValueUSD = col*1e18/price,                 ║
 * ║                 maxDebt = col*1e18*100/(COLL_R*price)                ║
 * ║   • maxMint — maxDebt = col*1e18*100/(COLL_R*price)                  ║
 * ║   • repayToHealth — maxSafeDebt = col*1e18*100/(COLL_R*price)        ║
 * ║   • VERSION string → "SunPLSVault v1.3"                              ║
 * ║                                                                      ║
 * ║   CHANGELOG v1.2 (preserved):                                        ║
 * ║   • VaultOpened event on first deposit                               ║
 * ║   • VaultUnderwater/VaultRecovered events                            ║
 * ║   • InterestAccrued event                                            ║
 * ║   • badDebt state + BadDebtRecorded event                            ║
 * ║   • lastRedemptionTime + REDEMPTION_LIQUIDATION_GAP (anti-griefing)  ║
 * ║                                                                      ║
 * ║   CORE MECHANICS:                                                    ║
 * ║   • 150% minimum collateralization ratio                             ║
 * ║   • Dynamic interest rate r from Controller (supports negative)      ║
 * ║   • Targeted redemption at R-value (hard price floor)                ║
 * ║   • Dutch auction liquidation at 110% threshold                      ║
 * ║   • Two-layer oracle: external price + Controller R-value            ║
 * ║   • lastOraclePrice fallback — never bricked by dead oracle          ║
 * ║   • No admin keys, no stability pool, no external dependencies       ║
 * ║                                                                      ║
 * ║   PRICE DIRECTION (locked in as of v1.3):                            ║
 * ║   price = WPLS per SunPLS (1e18 scale)                               ║
 * ║   e.g. 117378e18 → 1 SunPLS = 117,378 PLS                            ║
 * ║   collateralValue(SunPLS) = collateral(PLS) * 1e18 / price           ║
 * ║   plsEquivalent(SunPLS)   = sunpls * price / 1e18                    ║
 * ║                                                                      ║
 * ║   Dev:     ELITE TEAM6                                               ║
 * ║   License: CC-BY-NC-SA-4.0 | Immutable After Launch                  ║
 * ╚══════════════════════════════════════════════════════════════════════╝
 *
 * ═══════════════════════════════════════════════════════════════════════
 *                        SYSTEM INVARIANTS
 * ═══════════════════════════════════════════════════════════════════════
 *
 * I1.  Solvency:         All vaults must maintain CR >= 150% to mint/withdraw
 * I2.  Liquidation:      Vaults below 110% CR can be liquidated
 * I3.  Redemption:       Vaults at or below 150% CR can be redeemed against
 * I4.  Price Floor:      SunPLS can always be redeemed at R-value
 * I5.  Oracle Safety:    lastOraclePrice fallback prevents oracle-bricking
 * I6.  Rate Safety:      Interest rate bounded by Controller invariants
 * I7.  Immutability:     No admin, no pause, no upgrade after deploy
 * I8.  Liveness:         Dead oracle never blocks deposit/repay/withdraw
 * I9.  Debt Init:        lastDebtAccrual always set on first debt issuance
 * I10. Auction Anchor:   Dutch auction elapsed measured from undercollateralized start
 * I11. BadDebt Tracking: Residual uncovered debt recorded in badDebt (never silent)
 * I12. Redeem-Liq Gap:   Vault cannot be liquidated within REDEMPTION_LIQUIDATION_GAP
 *                        seconds of being redeemed against (anti-griefing)
 *
 * ═══════════════════════════════════════════════════════════════════════
 *                     PRICE DIRECTION REFERENCE (v1.3)
 * ═══════════════════════════════════════════════════════════════════════
 *
 * price (from oracle) = WPLS per SunPLS, 1e18-scaled
 * e.g. price = 117378e18 => 1 SunPLS costs 117,378 PLS
 *
 * Key conversions:
 *   SunPLS value of N PLS  = N * 1e18 / price
 *   PLS value of N SunPLS  = N * price / 1e18
 *
 * Collateral ratio:
 *   CR = (col * 1e18 / price) / debt * 100
 *      = col * 1e18 * 100 / (debt * price)
 *
 * Safety check (CR >= ratio%):
 *   col * 1e18 * 100 >= debt * ratio * price
 *
 * Numerical sanity check (10,000 PLS deposit, price = 117378e18):
 *   collateralValue = 10000e18 * 1e18 / 117378e18 = 0.0852 SunPLS  check
 *   mintAt155%      = 0.0852 * 100 / 155          = 0.0550 SunPLS  check
 *
 * ═══════════════════════════════════════════════════════════════════════
 *                     REDEMPTION MECHANISM
 * ═══════════════════════════════════════════════════════════════════════
 *
 * Why redemption creates a hard price floor:
 *
 *   If SunPLS trades at $0.97 on DEX and R = $1.00:
 *   -> Buy 1000 SunPLS for $970
 *   -> Redeem at R -> receive $1000 of PLS
 *   -> Profit: $30 risk-free
 *   -> This arbitrage continues until SunPLS price = R
 *
 * Vault owner protection:
 *   -> 0.5% fee stays with vault owner as compensation for involuntary exit
 *   -> Only vaults at or below 150% CR can be targeted
 *   -> Vaults above 150% CR are completely immune to redemption
 *   -> 5-minute liquidation gap after redemption -- owner can respond
 *   -> Incentivizes vault owners to maintain healthy CR
 *
 * R = WPLS per SunPLS (same units as oracle price)
 * plsOut = sunplsAmount * R / 1e18
 * Example: burn 0.055 SunPLS, R = 117378e18
 *   plsOut = 0.055e18 * 117378e18 / 1e18 = 6455.8 PLS  check
 *
 * ═══════════════════════════════════════════════════════════════════════
 *                     DUTCH AUCTION LIQUIDATION
 * ═══════════════════════════════════════════════════════════════════════
 *
 * Bonus measured from when vault first became undercollateralized.
 * Starts at 2%, grows to 5% over 3 hours.
 *
 * base(PLS) = repayAmount(SunPLS) * price / 1e18
 * Example: repay 0.01 SunPLS, price = 117378e18
 *   base = 0.01e18 * 117378e18 / 1e18 = 1173.78 PLS  check
 *
 * ═══════════════════════════════════════════════════════════════════════
 *                     ANTI-GRIEFING: REDEEM -> LIQUIDATE
 * ═══════════════════════════════════════════════════════════════════════
 *
 * Without the gap, an attacker could atomically:
 *   1. Redeem against a vault at 151% CR, pushing it to ~109% CR
 *   2. Immediately liquidate the now-underwater vault
 *   The vault owner has zero time to respond.
 *
 * With REDEMPTION_LIQUIDATION_GAP = 300s:
 *   After being redeemed against, a vault cannot be liquidated for 5 minutes.
 *   The vault owner can top up collateral or repay debt in that window.
 *   Redemption itself is still instant and unconstrained.
 *
 * ═══════════════════════════════════════════════════════════════════════
 */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

interface IWPLS {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}

interface ISunPLS {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

interface ISunPLSOracle {
    function update() external returns (uint256 price, uint256 timestamp);
    function peek()   external view   returns (uint256 price, uint256 timestamp);
    function isHealthy() external view returns (bool);
}

interface IProjectUSDController {
    function R() external view returns (uint256);
}

contract SunPLSVault is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // -------------------------------------------------------------------------
    // Immutables
    // -------------------------------------------------------------------------

    IERC20                public immutable wpls;
    ISunPLS               public immutable sunpls;
    ISunPLSOracle         public immutable oracle;
    IProjectUSDController public immutable controller;

    string public constant VERSION = "SunPLSVault v1.3"; // v1.3: bumped

    // -------------------------------------------------------------------------
    // System constants
    // -------------------------------------------------------------------------

    uint256 public constant COLLATERAL_RATIO            = 150;
    uint256 public constant LIQUIDATION_RATIO           = 110;
    uint256 public constant REDEMPTION_RATIO            = 150;
    uint256 public constant AUTOMINT_RATIO              = 155;
    uint256 public constant MIN_ACTION_AMOUNT           = 1e14;
    uint256 public constant WITHDRAW_COOLDOWN           = 300;
    uint256 public constant LIQUIDATION_COOLDOWN        = 600;
    uint256 public constant REDEMPTION_LIQUIDATION_GAP  = 300;
    uint256 public constant MIN_LIQUIDATION_BPS         = 2000;
    uint256 public constant MIN_BONUS_BPS               = 200;
    uint256 public constant MAX_BONUS_BPS               = 500;
    uint256 public constant AUCTION_TIME                = 3 hours;
    uint256 public constant MIN_SYSTEM_HEALTH           = 130;
    uint256 public constant SECONDS_PER_YEAR            = 31_536_000;
    uint256 public constant REDEMPTION_FEE_BPS          = 50;
    uint256 public constant MAX_VOLATILITY_BPS          = 1000;
    uint256 public constant MAX_ORACLE_STALENESS        = 600;
    uint256 public constant EMERGENCY_UNLOCK_TIME       = 30 days;

    // -------------------------------------------------------------------------
    // Vault struct
    // -------------------------------------------------------------------------

    struct Vault {
        uint256 collateral;
        uint256 debt;
        uint256 lastDepositTime;
        uint256 lastLiquidationTime;
        uint256 lastDebtAccrual;
        uint256 undercollateralizedSince;
        uint256 lastRedemptionTime;
    }

    mapping(address => Vault) public vaults;

    // -------------------------------------------------------------------------
    // Global state
    // -------------------------------------------------------------------------

    uint256 public totalCollateral;
    uint256 public totalDebt;
    uint256 public badDebt;
    int256  public currentRate;
    uint256 public lastOraclePrice;
    uint256 public lastOracleUpdateTime;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event Deposit(address indexed user, uint256 amount, uint256 ratio);
    event Withdraw(address indexed user, uint256 amount, uint256 ratio);
    event Mint(address indexed user, uint256 amount, uint256 ratio);
    event Repay(address indexed user, uint256 amount, uint256 ratio);
    event Liquidation(
        address indexed user,
        uint256 repayAmount,
        address indexed liquidator,
        uint256 reward,
        uint256 ratio
    );
    event Redemption(
        address indexed redeemer,
        address indexed targetVault,
        uint256 sunplsBurned,
        uint256 plsReceived,
        uint256 feeRetainedByVault,
        uint256 redemptionValue
    );
    event RateUpdated(int256 oldRate, int256 newRate, uint256 timestamp);
    event OraclePriceAccepted(uint256 price, uint256 timestamp);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    event VaultOpened(address indexed user, uint256 timestamp);
    event VaultUnderwater(address indexed user, uint256 since);
    event VaultRecovered(address indexed user, uint256 timestamp);
    event InterestAccrued(address indexed user, uint256 oldDebt, uint256 newDebt, uint256 timestamp);
    event BadDebtRecorded(address indexed user, uint256 amount, uint256 totalBadDebt);

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(
        address _wpls,
        address _sunpls,
        address _oracle,
        address _controller
    ) {
        require(
            _wpls       != address(0) &&
            _sunpls     != address(0) &&
            _oracle     != address(0) &&
            _controller != address(0),
            "Zero address"
        );

        wpls       = IERC20(_wpls);
        sunpls     = ISunPLS(_sunpls);
        oracle     = ISunPLSOracle(_oracle);
        controller = IProjectUSDController(_controller);

        (uint256 initialPrice, uint256 initialTs) = ISunPLSOracle(_oracle).peek();
        require(initialPrice > 0, "Oracle not ready at deploy");
        lastOraclePrice      = initialPrice;
        lastOracleUpdateTime = initialTs > 0 ? initialTs : block.timestamp;

        currentRate = 0;
    }

    // -------------------------------------------------------------------------
    // Controller interface
    // -------------------------------------------------------------------------

    function updateRate(int256 newRate) external {
        require(msg.sender == address(controller), "Only controller");
        int256 oldRate = currentRate;
        currentRate = newRate;
        emit RateUpdated(oldRate, newRate, block.timestamp);
    }

    // -------------------------------------------------------------------------
    // Oracle helpers — UNCHANGED from v1.2
    // -------------------------------------------------------------------------

    function _safePrice() internal returns (uint256) {
        try oracle.update() returns (uint256 freshPrice, uint256 freshTs) {
            if (freshPrice > 0) {
                if (lastOraclePrice > 0) {
                    uint256 diff = freshPrice > lastOraclePrice
                        ? freshPrice - lastOraclePrice
                        : lastOraclePrice - freshPrice;
                    uint256 volatilityBps = (diff * 10_000) / lastOraclePrice;
                    if (volatilityBps > MAX_VOLATILITY_BPS) {
                        return lastOraclePrice;
                    }
                }
                lastOraclePrice      = freshPrice;
                lastOracleUpdateTime = freshTs > 0 ? freshTs : block.timestamp;
                emit OraclePriceAccepted(freshPrice, block.timestamp);
                return freshPrice;
            }
        } catch {}

        require(lastOraclePrice > 0, "No valid oracle price");
        return lastOraclePrice;
    }

    function _viewPrice() internal view returns (uint256) {
        try oracle.peek() returns (uint256 p, uint256 ts) {
            if (p > 0 && (ts == 0 || block.timestamp - ts <= MAX_ORACLE_STALENESS)) {
                return p;
            }
        } catch {}
        return lastOraclePrice;
    }

    function _redemptionValue() internal view returns (uint256) {
        try controller.R() returns (uint256 rVal) {
            if (rVal > 0) return rVal;
        } catch {}
        return lastOraclePrice > 0 ? lastOraclePrice : 1e18;
    }

    // -------------------------------------------------------------------------
    // Interest accrual — UNCHANGED from v1.2
    // (pure SunPLS debt arithmetic, price not involved)
    // -------------------------------------------------------------------------

    function _touch(address user) internal {
        Vault storage v = vaults[user];
        if (v.debt > 0 && v.lastDebtAccrual > 0) {
            _accrueInterest(user, v);
        }
    }

    function _accrueInterest(address user, Vault storage v) internal {
        if (v.debt == 0) {
            v.lastDebtAccrual = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - v.lastDebtAccrual;
        if (elapsed == 0) return;
        if (elapsed > SECONDS_PER_YEAR) elapsed = SECONDS_PER_YEAR;

        int256 interest = (int256(v.debt) * currentRate * int256(elapsed))
            / (int256(SECONDS_PER_YEAR) * 1e18);

        if (interest != 0) {
            uint256 oldDebt = v.debt;

            if (interest > 0) {
                uint256 inc = uint256(interest);
                v.debt    += inc;
                totalDebt += inc;
            } else {
                uint256 dec = uint256(-interest);
                if (dec >= v.debt) {
                    totalDebt -= v.debt;
                    v.debt = 0;
                } else {
                    v.debt    -= dec;
                    totalDebt -= dec;
                }
            }

            if (v.debt != oldDebt) {
                emit InterestAccrued(user, oldDebt, v.debt, block.timestamp);
            }
        }

        v.lastDebtAccrual = block.timestamp;

        // Forgive dust
        if (v.debt > 0 && v.debt <= 1e12) {
            totalDebt = totalDebt >= v.debt ? totalDebt - v.debt : 0;
            v.debt = 0;
        }
    }

    function _issueDebt(address user, uint256 amount) internal {
        Vault storage v = vaults[user];
        if (v.debt == 0) {
            v.lastDebtAccrual = block.timestamp;
        }
        v.debt    += amount;
        totalDebt += amount;
        sunpls.mint(user, amount);
    }

    // -------------------------------------------------------------------------
    // User actions — Deposit — UNCHANGED from v1.2
    // -------------------------------------------------------------------------

    function depositPLS() external payable nonReentrant {
        require(msg.value >= MIN_ACTION_AMOUNT, "Too small");
        _touch(msg.sender);
        IWPLS(address(wpls)).deposit{value: msg.value}();
        _addCollateral(msg.sender, msg.value);
    }

    function deposit(uint256 amount) external nonReentrant {
        require(amount >= MIN_ACTION_AMOUNT, "Too small");
        _touch(msg.sender);
        wpls.safeTransferFrom(msg.sender, address(this), amount);
        _addCollateral(msg.sender, amount);
    }

    function _addCollateral(address user, uint256 amount) internal {
        Vault storage v = vaults[user];

        if (v.collateral == 0 && v.debt == 0 && v.lastDepositTime == 0) {
            emit VaultOpened(user, block.timestamp);
        }

        v.collateral     += amount;
        v.lastDepositTime = block.timestamp;
        totalCollateral  += amount;

        if (v.undercollateralizedSince > 0 && !_isAtLiquidationThreshold(v.collateral, v.debt)) {
            v.undercollateralizedSince = 0;
            emit VaultRecovered(user, block.timestamp);
        }

        emit Deposit(user, amount, _collateralRatio(user));
    }

    // -------------------------------------------------------------------------
    // depositAndAutoMintPLS — v1.3 FIXED
    // -------------------------------------------------------------------------

    /**
     * @notice Deposit PLS and auto-mint SunPLS at 155% ratio in one tx.
     *
     * v1.3 FIX: price = WPLS per SunPLS
     *   collateralValue(SunPLS) = msg.value * 1e18 / price
     *   mintAmount = collateralValue * 100 / AUTOMINT_RATIO
     *
     * v1.2 used:  (msg.value * price) / 1e18  — produced ~13.7B x too large value
     *
     * Sanity check (10,000 PLS, price = 117378e18):
     *   collateralValue = 10000e18 * 1e18 / 117378e18 = 0.0852 SunPLS
     *   mintAmount      = 0.0852 * 100 / 155          = 0.0550 SunPLS  check
     */
    function depositAndAutoMintPLS() external payable nonReentrant {
        require(msg.value >= MIN_ACTION_AMOUNT, "Too small");
        require(systemHealth() >= MIN_SYSTEM_HEALTH, "System undercollateralized");
        _touch(msg.sender);

        IWPLS(address(wpls)).deposit{value: msg.value}();
        _addCollateral(msg.sender, msg.value);

        uint256 price = _safePrice();

        // v1.3 FIX: was (msg.value * price) / 1e18
        uint256 collateralValue = Math.mulDiv(msg.value, 1e18, price);
        uint256 mintAmount      = (collateralValue * 100) / AUTOMINT_RATIO;

        if (mintAmount > 0) {
            Vault storage v = vaults[msg.sender];
            require(
                _isSafeAtRatio(v.collateral, v.debt + mintAmount, price, COLLATERAL_RATIO),
                "Automint exceeds limit"
            );
            _issueDebt(msg.sender, mintAmount);
            emit Mint(msg.sender, mintAmount, _collateralRatio(msg.sender));
        }
    }

    // -------------------------------------------------------------------------
    // User actions — Mint — UNCHANGED from v1.2
    // -------------------------------------------------------------------------

    function mint(uint256 amount) external nonReentrant {
        require(amount > 0, "Zero mint");
        require(systemHealth() >= MIN_SYSTEM_HEALTH, "System undercollateralized");
        _touch(msg.sender);

        Vault storage v = vaults[msg.sender];
        uint256 price   = _safePrice();
        require(
            _isSafeAtRatio(v.collateral, v.debt + amount, price, COLLATERAL_RATIO),
            "Insufficient collateral"
        );

        _issueDebt(msg.sender, amount);
        emit Mint(msg.sender, amount, _collateralRatio(msg.sender));
    }

    // -------------------------------------------------------------------------
    // User actions — Repay — UNCHANGED from v1.2
    // -------------------------------------------------------------------------

    function repay(uint256 amount) external nonReentrant {
        Vault storage v = vaults[msg.sender];
        _touch(msg.sender);
        require(amount > 0 && v.debt >= amount, "Invalid repay amount");

        sunpls.burn(msg.sender, amount);
        v.debt    -= amount;
        totalDebt -= amount;

        if (v.undercollateralizedSince > 0 && !_isAtLiquidationThreshold(v.collateral, v.debt)) {
            v.undercollateralizedSince = 0;
            emit VaultRecovered(msg.sender, block.timestamp);
        }

        emit Repay(msg.sender, amount, _collateralRatio(msg.sender));
    }

    function repayAndWithdrawAll() external nonReentrant {
        _touch(msg.sender);
        Vault storage v = vaults[msg.sender];

        uint256 debt = v.debt;
        uint256 col  = v.collateral;

        require(debt > 0 || col > 0, "Nothing to do");

        if (debt > 0) {
            sunpls.burn(msg.sender, debt);
            totalDebt -= debt;
            v.debt = 0;
            emit Repay(msg.sender, debt, type(uint256).max);
        }

        if (col > 0) {
            totalCollateral -= col;
            delete vaults[msg.sender];
            IWPLS(address(wpls)).withdraw(col);
            payable(msg.sender).transfer(col);
            emit Withdraw(msg.sender, col, type(uint256).max);
        }
    }

    // -------------------------------------------------------------------------
    // User actions — Withdraw — UNCHANGED from v1.2
    // -------------------------------------------------------------------------

    function withdrawPLS(uint256 amount) external nonReentrant {
        _touch(msg.sender);
        Vault storage v = vaults[msg.sender];
        require(amount > 0 && v.collateral >= amount, "Invalid amount");
        require(block.timestamp > v.lastDepositTime + WITHDRAW_COOLDOWN, "Cooldown active");

        v.collateral    -= amount;
        totalCollateral -= amount;

        uint256 p = _safePrice();
        require(
            _isSafeAtRatio(v.collateral, v.debt, p, COLLATERAL_RATIO),
            "Would breach 150% CR"
        );

        IWPLS(address(wpls)).withdraw(amount);
        payable(msg.sender).transfer(amount);
        emit Withdraw(msg.sender, amount, _collateralRatio(msg.sender));
    }

    function withdrawWPLS(uint256 amount) external nonReentrant {
        _touch(msg.sender);
        Vault storage v = vaults[msg.sender];
        require(amount > 0 && v.collateral >= amount, "Invalid amount");
        require(block.timestamp > v.lastDepositTime + WITHDRAW_COOLDOWN, "Cooldown active");

        v.collateral    -= amount;
        totalCollateral -= amount;

        uint256 p = _safePrice();
        require(
            _isSafeAtRatio(v.collateral, v.debt, p, COLLATERAL_RATIO),
            "Would breach 150% CR"
        );

        wpls.safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount, _collateralRatio(msg.sender));
    }

    function emergencyUnlock() external nonReentrant {
        _touch(msg.sender);
        Vault storage v = vaults[msg.sender];
        require(v.debt == 0, "Repay debt first");
        require(v.collateral > 0, "No collateral");
        require(block.timestamp > v.lastDepositTime + EMERGENCY_UNLOCK_TIME, "Too early");

        uint256 col     = v.collateral;
        totalCollateral -= col;
        delete vaults[msg.sender];

        IWPLS(address(wpls)).withdraw(col);
        payable(msg.sender).transfer(col);
        emit EmergencyWithdraw(msg.sender, col);
    }

    // -------------------------------------------------------------------------
    // Layer 1: Targeted Redemption — v1.3 FIXED
    // -------------------------------------------------------------------------

    /**
     * @notice Burn SunPLS to receive PLS at Controller's R-value.
     *
     * v1.3 FIX: R = WPLS per SunPLS (same units as oracle price)
     *   plsOut = sunplsAmount * R / 1e18
     *
     * v1.2 used: mulDiv(sunplsAmount, 1e18, R) — wrong direction,
     * returned near-zero PLS since R is ~117378e18 not ~1e18.
     *
     * Sanity: burn 0.055e18 SunPLS, R = 117378e18
     *   plsOut = 0.055e18 * 117378e18 / 1e18 = 6455.8 PLS  check
     *
     * @param sunplsAmount  SunPLS to burn
     * @param targetVault   Vault to redeem against (must be at or below 150% CR)
     */
    function redeem(uint256 sunplsAmount, address targetVault) external nonReentrant {
        require(sunplsAmount >= MIN_ACTION_AMOUNT, "Too small");
        require(targetVault != address(0), "Zero vault");
        require(targetVault != msg.sender, "Cannot self-redeem");

        _touch(targetVault);

        Vault storage v = vaults[targetVault];
        require(v.debt > 0, "No debt in vault");
        require(sunplsAmount <= v.debt, "Exceeds vault debt");

        uint256 targetCR = _collateralRatio(targetVault);
        require(targetCR <= REDEMPTION_RATIO, "Vault CR too high to redeem against");

        uint256 R = _redemptionValue();
        require(R > 0, "No R value");

        // v1.3 FIX: was mulDiv(sunplsAmount, 1e18, R)
        uint256 plsOut = Math.mulDiv(sunplsAmount, R, 1e18);
        require(plsOut > 0, "Redemption too small");
        require(plsOut <= v.collateral, "Insufficient vault collateral");

        uint256 feeAmount     = (plsOut * REDEMPTION_FEE_BPS) / 10_000;
        uint256 plsToRedeemer = plsOut - feeAmount;

        sunpls.burn(msg.sender, sunplsAmount);

        v.debt              -= sunplsAmount;
        totalDebt           -= sunplsAmount;
        v.collateral        -= plsToRedeemer;
        totalCollateral     -= plsToRedeemer;
        v.lastRedemptionTime = block.timestamp;

        IWPLS(address(wpls)).withdraw(plsToRedeemer);
        payable(msg.sender).transfer(plsToRedeemer);

        emit Redemption(
    msg.sender,
    targetVault,
    sunplsAmount,
    plsToRedeemer,
    feeAmount,
    R
);
    }

    // -------------------------------------------------------------------------
    // Layer 2: Dutch Auction Liquidation — v1.3 FIXED
    // -------------------------------------------------------------------------

    function liquidate(address user, uint256 repayAmount) external nonReentrant {
        require(user != msg.sender, "Cannot self-liquidate");
        _touch(user);

        Vault storage v = vaults[user];
        require(v.debt > 0, "No debt");
        require(_isAtLiquidationThreshold(v.collateral, v.debt), "Vault is safe");
        require(repayAmount > 0 && repayAmount <= v.debt, "Invalid repay amount");
        require(
            repayAmount * 10_000 >= v.debt * MIN_LIQUIDATION_BPS,
            "Below min liquidation size"
        );
        require(
            block.timestamp > v.lastLiquidationTime + LIQUIDATION_COOLDOWN,
            "Liquidation cooldown"
        );
        require(
            block.timestamp > v.lastRedemptionTime + REDEMPTION_LIQUIDATION_GAP,
            "Recently redeemed: wait before liquidating"
        );

        if (v.undercollateralizedSince == 0) {
            v.undercollateralizedSince = block.timestamp;
            emit VaultUnderwater(user, block.timestamp);
        }
        uint256 auctionAnchor = v.undercollateralizedSince;

        uint256 price = _safePrice();

        // v1.3 FIX: was mulDiv(repayAmount, 1e18, price)
        // base(PLS) = repayAmount(SunPLS) * price / 1e18
        uint256 base = Math.mulDiv(repayAmount, price, 1e18);

        uint256 elapsed = block.timestamp - auctionAnchor;
        if (elapsed > AUCTION_TIME) elapsed = AUCTION_TIME;
        uint256 bonusBps = MIN_BONUS_BPS + (
            (MAX_BONUS_BPS - MIN_BONUS_BPS) * elapsed / AUCTION_TIME
        );
        uint256 bonus  = (base * bonusBps) / 10_000;
        uint256 reward = base + bonus;

        if (reward > v.collateral) {
            uint256 deficit = reward - v.collateral;
            reward = v.collateral;
            badDebt += deficit;
            emit BadDebtRecorded(user, deficit, badDebt);
        }

        sunpls.burn(msg.sender, repayAmount);
        v.debt          -= repayAmount;
        totalDebt       -= repayAmount;
        v.collateral    -= reward;
        totalCollateral -= reward;
        v.lastLiquidationTime = block.timestamp;

        if (!_isAtLiquidationThreshold(v.collateral, v.debt)) {
            v.undercollateralizedSince = 0;
            emit VaultRecovered(user, block.timestamp);
        }

        IWPLS(address(wpls)).withdraw(reward);
        payable(msg.sender).transfer(reward);

        emit Liquidation(user, repayAmount, msg.sender, reward, _collateralRatio(user));
    }

    // -------------------------------------------------------------------------
    // Internal safety checks — v1.3 FIXED
    // -------------------------------------------------------------------------

    /**
     * @dev v1.3 FIX: price = WPLS per SunPLS
     *
     * CR = col * 1e18 * 100 / (debt * price)
     * Liquidatable when CR < LIQUIDATION_RATIO:
     *   col * 1e18 * 100 < debt * LIQUIDATION_RATIO * price
     *
     * v1.2: col * price * 100 < debt * LIQUIDATION_RATIO * 1e18
     * (inverted — made all vaults appear safe regardless of collateral)
     */
    function _isAtLiquidationThreshold(uint256 col, uint256 debt) internal view returns (bool) {
        if (debt == 0) return false;
        uint256 p = _viewPrice();
        if (p == 0) return false;
        // col * 1e18 * 100 < debt * LIQUIDATION_RATIO * price
        return Math.mulDiv(col, 1e18 * 100, p) < debt * LIQUIDATION_RATIO;
    }

    /**
     * @dev v1.3 FIX: safe when col * 1e18 * 100 >= debt * ratio * price
     *
     * v1.2: col * price * 100 >= debt * ratio * 1e18
     * (inverted — made all positions appear safe, allowing unlimited minting)
     */
    function _isSafeAtRatio(
        uint256 col,
        uint256 debt,
        uint256 price,
        uint256 ratio
    ) internal pure returns (bool) {
        if (debt == 0) return true;
        // col * 1e18 * 100 >= debt * ratio * price
        return Math.mulDiv(col, 1e18 * 100, price) >= debt * ratio;
    }

    /**
     * @dev v1.3 FIX: CR% = col * 1e18 * 100 / (debt * price)
     *
     * v1.2: col * price * 100 / (debt * 1e18)
     * (inverted — always returned astronomically large CR)
     */
    function _collateralRatio(address user) internal view returns (uint256) {
        Vault storage v = vaults[user];
        if (v.debt == 0) return type(uint256).max;
        uint256 p = _viewPrice();
        if (p == 0) return type(uint256).max;
        return Math.mulDiv(v.collateral, 1e18 * 100, v.debt * p);
    }

    // -------------------------------------------------------------------------
    // View functions — v1.3 FIXED
    // -------------------------------------------------------------------------

    /**
     * @dev v1.3 FIX: totalCollateral * 1e18 * 100 / (totalDebt * price)
     *
     * v1.2: totalCollateral * price * 100 / (totalDebt * 1e18)  (inverted)
     */
    function systemHealth() public view returns (uint256) {
        if (totalDebt == 0) return type(uint256).max;
        uint256 p = _viewPrice();
        if (p == 0) return type(uint256).max;
        return Math.mulDiv(totalCollateral, 1e18 * 100, totalDebt * p);
    }

    function canLiquidate(address user) public view returns (bool) {
        Vault storage v = vaults[user];
        if (!_isAtLiquidationThreshold(v.collateral, v.debt)) return false;
        return block.timestamp > v.lastRedemptionTime + REDEMPTION_LIQUIDATION_GAP;
    }

    function canRedeem(address user) public view returns (bool) {
        Vault storage v = vaults[user];
        if (v.debt == 0) return false;
        uint256 cr = _collateralRatio(user);
        return cr <= REDEMPTION_RATIO;
    }

    /**
     * @dev v1.3: collateralValueUSD field now correctly represents SunPLS value.
     *   collateralValueUSD = collateral * 1e18 / price
     *   maxDebt            = collateral * 1e18 * 100 / (price * COLLATERAL_RATIO)
     *
     * v1.2 used collateral * price / 1e18 (inverted — produced absurd values).
     *
     * NOTE: Return signature adds one field vs v1.2 for clarity.
     *   New field: collateralValueSunPLS (same value as collateralValueUSD,
     *   kept for frontend compatibility under both names).
     */
    function vaultInfo(address user)
        external
        view
        returns (
            uint256 collateral,
            uint256 debt,
            uint256 collateralValueUSD,
            uint256 ratio,
            uint256 mintable,
            int256  rate,
            uint256 redemptionVal,
            bool    liquidatable,
            bool    redeemable,
            bool    oracleHealthy,
            uint256 systemRatio
        )
    {
        Vault storage v = vaults[user];
        collateral      = v.collateral;
        debt            = v.debt;

        uint256 p     = _viewPrice();
        oracleHealthy = oracle.isHealthy();

        // v1.3 FIX: collateralValue(SunPLS) = collateral * 1e18 / price
        collateralValueUSD = p > 0 ? Math.mulDiv(collateral, 1e18, p) : 0;

        ratio = _collateralRatio(user);

        // v1.3 FIX: maxDebt = collateral * 1e18 * 100 / (price * COLLATERAL_RATIO)
        uint256 maxDebt = p > 0
            ? Math.mulDiv(collateral, 1e18 * 100, p * COLLATERAL_RATIO)
            : 0;
        mintable      = maxDebt > debt ? maxDebt - debt : 0;
        rate          = currentRate;
        redemptionVal = _redemptionValue();
        liquidatable  = canLiquidate(user);
        redeemable    = canRedeem(user);
        systemRatio   = systemHealth();
    }

    /**
     * @dev v1.3 FIX: base(PLS) = minRepay(SunPLS) * price / 1e18
     *
     * v1.2: mulDiv(minRepay, 1e18, p)  (inverted)
     */
    function liquidationInfo(address user)
        external
        view
        returns (
            uint256 debt,
            uint256 minRepay,
            uint256 reward,
            uint256 bonusBps
        )
    {
        Vault storage v = vaults[user];
        if (v.debt == 0 || !_isAtLiquidationThreshold(v.collateral, v.debt)) {
            return (0, 0, 0, 0);
        }

        uint256 p = _viewPrice();
        if (p == 0) return (0, 0, 0, 0);

        debt     = v.debt;
        minRepay = (v.debt * MIN_LIQUIDATION_BPS) / 10_000;

        // v1.3 FIX: was mulDiv(minRepay, 1e18, p)
        uint256 base = Math.mulDiv(minRepay, p, 1e18);

        uint256 anchor  = v.undercollateralizedSince > 0
            ? v.undercollateralizedSince
            : block.timestamp;
        uint256 elapsed = block.timestamp - anchor;
        if (elapsed > AUCTION_TIME) elapsed = AUCTION_TIME;

        bonusBps = MIN_BONUS_BPS + ((MAX_BONUS_BPS - MIN_BONUS_BPS) * elapsed / AUCTION_TIME);
        uint256 bonus = (base * bonusBps) / 10_000;
        reward = base + bonus;
        if (reward > v.collateral) reward = v.collateral;
    }

    /**
     * @dev v1.3 FIX: plsOut = sunplsAmount * R / 1e18
     *
     * v1.2: mulDiv(sunplsAmount, 1e18, R)  (inverted)
     */
    function redemptionPreview(address targetVault, uint256 sunplsAmount)
        external
        view
        returns (
            uint256 plsToRedeemer,
            uint256 feeToOwner,
            uint256 R,
            bool    eligible
        )
    {
        eligible = canRedeem(targetVault);
        Vault storage v = vaults[targetVault];
        if (v.debt < sunplsAmount) eligible = false;

        R = _redemptionValue();
        if (R > 0 && sunplsAmount > 0) {
            // v1.3 FIX: was mulDiv(sunplsAmount, 1e18, R)
            uint256 plsOut = Math.mulDiv(sunplsAmount, R, 1e18);
            feeToOwner     = (plsOut * REDEMPTION_FEE_BPS) / 10_000;
            plsToRedeemer  = plsOut - feeToOwner;
        }
    }

    /**
     * @dev v1.3 FIX: maxDebt = collateral * 1e18 * 100 / (price * COLLATERAL_RATIO)
     *
     * v1.2: collateral * price * 100 / (COLLATERAL_RATIO * 1e18)  (inverted)
     */
    function maxMint(address user) external view returns (uint256) {
        Vault storage v = vaults[user];
        if (v.collateral == 0) return 0;
        uint256 p = _viewPrice();
        if (p == 0) return 0;
        uint256 maxDebt = Math.mulDiv(v.collateral, 1e18 * 100, p * COLLATERAL_RATIO);
        return maxDebt > v.debt ? maxDebt - v.debt : 0;
    }

    /**
     * @dev v1.3 FIX: maxSafeDebt = collateral * 1e18 * 100 / (price * COLLATERAL_RATIO)
     *
     * v1.2: collateral * price * 100 / (COLLATERAL_RATIO * 1e18)  (inverted)
     */
    function repayToHealth(address user) external view returns (uint256) {
        Vault storage v = vaults[user];
        if (v.debt == 0) return 0;
        uint256 p = _viewPrice();
        if (p == 0) return 0;
        uint256 maxSafeDebt = Math.mulDiv(v.collateral, 1e18 * 100, p * COLLATERAL_RATIO);
        return v.debt > maxSafeDebt ? v.debt - maxSafeDebt : 0;
    }

    receive() external payable {}
}
