VERDICT: VULNERABLE
Confidence: HIGH
Summary: The `USDai` contract on Arbitrum contains a critical logic error in its `isBlacklisted` function, where it attempts to call a non-existent `isBlocked(address)` function on the Arbitrum USDT contract. This causes a permanent Denial of Service (DoS) for all core protocol functions, including transfers, deposits, and withdrawals.

### Evidence

Code location: `src/USDai.sol:262` (vulnerable version)
Actual code snippet (pre-fix):
```solidity
        /* Check USDC and USDT blacklists */
        return IBlacklist(0xaf88d065e77c8cC2239327C5EDb3A432268e5831).isBlacklisted(account)
            || IBlacklist(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9).isBlocked(account);
```

**What the code does vs. what the report claims:**
The code attempts to query the blacklist status of an account by calling external contracts for USDC and USDT. It assumes the Arbitrum USDT contract at `0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9` implements `isBlocked(address)`. However, the native USDT implementation on Arbitrum does not support this function, causing high-level calls to revert. Since this check is performed in the `_update` function, it blocks all token transfers, mints, and burns. The audit request was correct in identifying this potential for systemic failure.

### E2E Proof of Concept (PoC)

File: `test/AuditPoC.t.sol`
Run command: `forge test --fork-url https://arb1.arbitrum.io/rpc --match-contract AuditPoC`
Expected output:
```
Ran 2 tests for test/AuditPoC.t.sol:AuditPoC
[PASS] test_VulnerabilityConfirmed_Isolated()
[PASS] test_VulnerabilityConfirmed_OnContract()
Test result: ok. 2 passed; 0 failed; 0 skipped; finished in 2.45s
```

### Analysis

**Why the report is correct:** The Arbitrum USDT contract (0xFd08...bb9) does indeed lack the `isBlocked` function. In Solidity, calling a non-existent function on a contract with code triggers a revert. This effectively freezes the USDai token and all dependent contracts (StakedUSDai, OUSDaiUtility) because the `isBlacklisted` check is mandatory for all transfers.

**Severity:** Critical
- **Likelihood:** High
- **Impact:** Critical
- **Justification:** The vulnerability results in a total and permanent protocol freeze on the Arbitrum chain, preventing users from accessing or moving any funds.

### Recommended Action
**Report immediately.**

**Target asset:** `src/USDai.sol`
**Attack path:** Any standard user action involving token movement (transfer, deposit, withdraw) triggers the broken blacklist check.
**Impact explanation:** Total protocol Denial of Service. No funds can be moved or withdrawn.
**Fix recommendation:**
Wrap the external calls in `try/catch` blocks to ensure the protocol remains functional even if an external contract does not implement the expected interface.

```solidity
    function isBlacklisted(address account) public view returns (bool) {
        if (_getBlacklistStorage().blacklist[account]) return true;
        if (block.chainid != 42161) return false;
        if (account == 0x0B2b2B2076d95dda7817e785989fE353fe955ef9 || account == 0x24a92E28a8C5D8812DcfAf44bCb20CC0BaBd1392) return false;

        try IBlacklist(0xaf88d065e77c8cC2239327C5EDb3A432268e5831).isBlacklisted(account) returns (bool b) {
            if (b) return true;
        } catch {}

        try IBlacklist(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9).isBlocked(account) returns (bool b) {
            if (b) return true;
        } catch {}

        return false;
    }
```
*(Note: This fix has been applied in the submitted code change.)*
