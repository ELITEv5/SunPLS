// SPDX-License-Identifier: CC-BY-NC-SA-4.0
pragma solidity ^0.8.20;

/**
 * ╔══════════════════════════════════════════════════════════════════════╗
 * ║                     SunPLS Token v1.3 — ELITE TEAM6                  ║
 * ║                     Autonomous Stable Asset                          ║
 * ║                                                                      ║
 * ║   • Mint/burn controlled exclusively by Vault (post-latch)           ║
 * ║   • Vault address set via one-time latch after Vault deploys         ║
 * ║   • 1000 SunPLS minted to deployer at construction for LP seed       ║
 * ║   • No deployer powers after setVault() is called                    ║
 * ║   • Immutable after latch — forever                                  ║
 * ║                                                                      ║
 * ║   CHANGELOG v1.3:                                                    ║
 * ║   • Replaced bootstrap() function with constructor mint.             ║
 * ║     1000 SunPLS minted directly to deployer at deploy time.          ║
 * ║     Eliminates deployer-callable mint function visible to scanners   ║
 * ║     and token analytics platforms (Dexscreener etc).                 ║
 * ║     Removed: bootstrap(), bootstrapUsed, MAX_BOOTSTRAP_SUPPLY,       ║
 * ║     BootstrapMint event. Constructor mint is simpler, cleaner,       ║
 * ║     and produces identical on-chain outcome with zero scanner risk.  ║
 * ║                                                                      ║
 * ║   CHANGELOG v1.2:                                                    ║
 * ║   • Added bootstrap(address to, uint256 amount) — now removed.       ║
 * ║                                                                      ║
 * ║   CHANGELOG v1.1:                                                    ║
 * ║   • Removed _vault constructor parameter. vault is now set via       ║
 * ║     setVault(address) — a one-time latch callable only by the        ║
 * ║     deployer. After setVault() is called, vaultSet latches true      ║
 * ║     permanently and the function reverts for all future callers      ║
 * ║     including the deployer. Eliminates Token <-> Vault circular      ║
 * ║     deployment dependency without requiring nonce prediction.        ║
 * ║   • mint() and burn() require vaultSet before executing.             ║
 * ║   • deployer stored as immutable — set once at construction.         ║
 * ║   • VaultSet(address vault) event emitted on latch.                  ║
 * ║   • Post-latch security identical to v1.0 immutable design.          ║
 * ║                                                                      ║
 * ║   DEPLOYMENT SEQUENCE:                                               ║
 * ║   Step 1:  Deploy Token        (1000 SUNPLS minted to deployer)      ║
 * ║   Step 2:  Create PulseX SunPLS/WPLS pair + seed with deploy mint    ║
 * ║   Step 3:  Deploy Oracle       (pair, wpls, token)                   ║
 * ║   Step 4:  Deploy Controller   (oracle, initialR, epoch, k, alpha)   ║
 * ║   Step 5:  Deploy Vault v1.3   (wpls, token, oracle, controller)     ║
 * ║   Step 6:  token.setVault(vault)       <- latches forever            ║
 * ║   Step 7:  controller.setVault(vault)  <- latches forever            ║
 * ║   Step 8:  depositAndAutoMintPLS() to mint real SunPLS via vault     ║
 * ║   Step 9:  Deepen PulseX pool with vault-minted SunPLS               ║
 * ║                                                                      ║
 * ║   Dev:     ELITE TEAM6                                               ║
 * ║   Website: https://www.sundaitoken.com                               ║
 * ║   License: CC-BY-NC-SA-4.0 | Immutable After Launch                  ║
 * ╚══════════════════════════════════════════════════════════════════════╝
 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SunPLS is ERC20 {

    // ─────────────────────────────────────────────────────────────────────
    // Deployer — immutable, used only to gate setVault()
    // ─────────────────────────────────────────────────────────────────────

    /// @notice Deployer address. Only power: call setVault() once.
    ///         Zero ongoing authority after setVault() is called.
    address private immutable deployer;

    // ─────────────────────────────────────────────────────────────────────
    // Vault — one-time latch
    // ─────────────────────────────────────────────────────────────────────

    /// @notice The only address authorized to mint or burn (post-latch).
    ///         address(0) until setVault() is called.
    ///         Immutable in practice — cannot be changed after latch closes.
    address public vault;

    /// @notice True once setVault() has been called. Permanently latched.
    bool public vaultSet;

    /// @notice Total SunPLS minted to deployer at construction for LP seed.
    uint256 public constant SEED_SUPPLY = 1000 * 1e18;

    // ─────────────────────────────────────────────────────────────────────
    // Events
    // ─────────────────────────────────────────────────────────────────────

    /// @notice Emitted once when vault address is permanently set.
    event VaultSet(address indexed vault);

    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);

    // ─────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────

    /**
     * @notice Deploy SunPLS token and mint 1000 SUNPLS to deployer.
     *
     * @dev    The 1000 SUNPLS seed supply exists solely to allow the deployer
     *         to create and seed the PulseX SunPLS/WPLS pair before the oracle
     *         is deployed. The oracle constructor requires both reserves > 0.
     *
     *         No mint function is callable by the deployer after construction.
     *         All future minting is exclusively vault-controlled post-latch.
     *
     *         The seed supply is tiny relative to vault-minted supply and
     *         will be diluted immediately as real CDP positions are opened.
     */
    constructor() ERC20("SunPLS", "SUNPLS") {
        deployer = msg.sender;
        _mint(msg.sender, SEED_SUPPLY);
    }

    // ─────────────────────────────────────────────────────────────────────
    // One-time vault latch
    // ─────────────────────────────────────────────────────────────────────

    /**
     * @notice Set the vault address. Callable exactly once by the deployer.
     *
     * @dev Called after Vault is deployed (Step 6 of deployment sequence).
     *      Once called, vaultSet latches true permanently. The deployer
     *      has no further authority over this contract.
     *
     * @param _vault Address of the deployed SunPLSVault contract.
     */
    function setVault(address _vault) external {
        require(msg.sender == deployer, "Only deployer");
        require(!vaultSet,              "Vault already set");
        require(_vault != address(0),   "Zero vault address");

        vault    = _vault;
        vaultSet = true;

        emit VaultSet(_vault);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Mint / Burn — vault only, requires latch closed
    // ─────────────────────────────────────────────────────────────────────

    /**
     * @notice Mint SunPLS to an address.
     * @dev    Only callable by the vault. No exceptions.
     *         Requires vaultSet — no minting before vault is linked.
     *         Called when a user opens or increases a CDP position.
     */
    function mint(address to, uint256 amount) external {
        require(vaultSet,            "Vault not set");
        require(msg.sender == vault, "Only vault");
        _mint(to, amount);
        emit Mint(to, amount);
    }

    /**
     * @notice Burn SunPLS from an address.
     * @dev    Only callable by the vault. No exceptions.
     *         Requires vaultSet — no burning before vault is linked.
     *         Called on repay, liquidation, or redemption.
     *         Caller must hold sufficient balance — ERC20 enforces this.
     */
    function burn(address from, uint256 amount) external {
        require(vaultSet,            "Vault not set");
        require(msg.sender == vault, "Only vault");
        _burn(from, amount);
        emit Burn(from, amount);
    }
}
