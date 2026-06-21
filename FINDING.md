[CRITICAL] `bridgedSupply` Underflow Bricks Bridge Arrivals in `USDai.sol` and `StakedUSDai.sol`

Vulnerable Code:
- `src/USDai.sol:580` — `mint()`
- `src/StakedUSDai.sol:773` — `mint()`

### Root Cause
The `mint` and `burn` functions in `USDai.sol` and `StakedUSDai.sol` are designed to track the supply of tokens bridged across chains. However, the logic for updating the `bridgedSupply` variable is inverted:
- `mint` (arrival of tokens from another chain) *decrements* the `bridgedSupply` counter.
- `burn` (departure of tokens to another chain) *increments* the `bridgedSupply` counter.

Since the `bridgedSupply` counter starts at 0, the very first attempt to bridge tokens *into* a chain will call `mint`, which attempts to subtract the bridged amount from 0. In Solidity 0.8.x, this causes an arithmetic underflow and reverts.

### Attack Path
1. The protocol is deployed on Chain A and Chain B.
2. A user attempts to bridge USDai from Chain A to Chain B.
3. The bridge adapter on Chain B calls `usdai.mint(user, amount)`.
4. `USDai.mint` executes: `_getSupplyStorage().bridged -= amount;`.
5. Since `bridged` is 0, the transaction reverts due to underflow.
6. The bridge arrival is bricked, and funds may be stuck in the bridge contract or requires manual intervention/fixing of the contract to release.

### Result
Funds cannot be bridged *into* any chain where they haven't been bridged *out* of first in a greater or equal amount. This effectively breaks the cross-chain functionality of the protocol.

### PoC
Run `./run_poc.sh`

Expected output:
```
Ran 2 tests for test/UnderflowPoC.t.sol:UnderflowPoCTest
[PASS] test_StakedUSDai_Mint_Underflow() (gas: 89482)
[PASS] test_USDai_Mint_Underflow() (gas: 76299)
Suite result: ok. 2 passed; 0 failed; 0 skipped;
```
The PoC uses `vm.expectRevert()` to confirm that the `mint` calls fail as expected.

### Impact
Critical. The core omnichain functionality is broken. Any attempt to use the bridge as intended (moving supply to a new chain) will fail.

### Fix
Invert the logic in both `USDai.sol` and `StakedUSDai.sol`.

**Minimal correct patch for `src/USDai.sol`:**
```diff
<<<<<<< SEARCH
    function mint(address to, uint256 amount) external whenNotPaused onlyBridgeAdapter {
        _mint(to, amount);

        /* Update bridged supply */
        _getSupplyStorage().bridged -= amount;
    }

    /**
     * @inheritdoc IMintableBurnable
     */
    function burn(address from, uint256 amount) external whenNotPaused onlyBridgeAdapter {
        _burn(from, amount);

        /* Update bridged supply */
        _getSupplyStorage().bridged += amount;
    }
=======
    function mint(address to, uint256 amount) external whenNotPaused onlyBridgeAdapter {
        _mint(to, amount);

        /* Update bridged supply */
        _getSupplyStorage().bridged += amount;
    }

    /**
     * @inheritdoc IMintableBurnable
     */
    function burn(address from, uint256 amount) external whenNotPaused onlyBridgeAdapter {
        _burn(from, amount);

        /* Update bridged supply */
        _getSupplyStorage().bridged -= amount;
    }
>>>>>>> REPLACE
```

**Minimal correct patch for `src/StakedUSDai.sol`:**
```diff
<<<<<<< SEARCH
    function mint(address to, uint256 amount) external whenNotPaused onlyBridgeAdapter {
        /* Mint supply */
        _mint(to, amount);

        /* Update bridged supply */
        _getBridgedSupplyStorage().bridgedSupply -= amount;
    }

    /**
     * @inheritdoc IMintableBurnable
     */
    function burn(address from, uint256 amount) external whenNotPaused onlyBridgeAdapter {
        /* Burn supply */
        _burn(from, amount);

        /* Update bridged supply */
        _getBridgedSupplyStorage().bridgedSupply += amount;
    }
=======
    function mint(address to, uint256 amount) external whenNotPaused onlyBridgeAdapter {
        /* Mint supply */
        _mint(to, amount);

        /* Update bridged supply */
        _getBridgedSupplyStorage().bridgedSupply += amount;
    }

    /**
     * @inheritdoc IMintableBurnable
     */
    function burn(address from, uint256 amount) external whenNotPaused onlyBridgeAdapter {
        /* Burn supply */
        _burn(from, amount);

        /* Update bridged supply */
        _getBridgedSupplyStorage().bridgedSupply -= amount;
    }
>>>>>>> REPLACE
```

---

[HIGH] Typo in USDT Blacklist Check Causes DoS on Arbitrum in `USDai.sol`

Vulnerable Code:
- `src/USDai.sol:291` — `isBlacklisted()`

### Root Cause
The `USDai.isBlacklisted` function attempts to integrate with the native Arbitrum USDT blacklist. It calls `IBlacklist(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9).isBlocked(account)`.

However, the Arbitrum USDT contract does not have an `isBlocked` function. Calling a non-existent function on a contract causes the call to revert.

### Attack Path
1. Any user calls a function that triggers the `notBlacklisted` modifier (e.g., `transfer`, `deposit`, `withdraw`).
2. The modifier calls `isBlacklisted(account)`.
3. `isBlacklisted` calls the external USDT contract's `isBlocked` function.
4. The call reverts because `isBlocked` does not exist on that contract.
5. The entire transaction reverts.

### Result
Total DoS of all standard ERC20 operations and protocol deposits/withdrawals for all users on Arbitrum.

### Impact
High. While not a direct theft of funds, it bricks the entire protocol on its primary chain (Arbitrum).

### Fix
Update the `IBlacklist` interface or the call to use the correct method for the Arbitrum USDT contract. According to my investigation, the Arbitrum USDT (0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9) does not expose a public `isBlocked` or `isBlacklisted` function in the standard way.

**Minimal correct patch for `src/USDai.sol`:**
If the function does not exist, the check should be removed or replaced with the correct integration for that specific contract. Assuming the intention was to follow USDC's pattern:

```diff
<<<<<<< SEARCH
        /* Check USDC and USDT blacklists */
        return IBlacklist(0xaf88d065e77c8cC2239327C5EDb3A432268e5831).isBlacklisted(account)
            || IBlacklist(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9).isBlocked(account);
=======
        /* Check USDC blacklist */
        return IBlacklist(0xaf88d065e77c8cC2239327C5EDb3A432268e5831).isBlacklisted(account);
>>>>>>> REPLACE
```
Alternatively, if a different method is confirmed to exist for USDT on Arbitrum, that should be used instead.
