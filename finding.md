# Security Audit Finding: Critical DoS on Arbitrum

**VERDICT: VULNERABLE**
**Confidence: HIGH**

## Summary
The `USDai` contract on Arbitrum is susceptible to a permanent Denial of Service (DoS) because its `isBlacklisted` function attempts to call a non-existent `isBlocked(address)` function on the official Arbitrum USDT contract. This causes all `USDai` transfers, deposits, and withdrawals to revert, effectively freezing the entire protocol.

## Evidence

- **Code location:** `src/USDai.sol:184-190`
- **Actual code snippet:**
```solidity
    function isBlacklisted(
        address account
    ) public view returns (bool) {
        /* Check local blacklist */
        if (_getBlacklistStorage().blacklist[account]) return true;

        /* If not on Arbitrum, skip remaining checks */
        if (block.chainid != 42161) return false;

        /* Exclude Staked USDai and OUSDaiUtility */
        if (
            account == 0x0B2b2B2076d95dda7817e785989fE353fe955ef9
                || account == 0x24a92E28a8C5D8812DcfAf44bCb20CC0BaBd1392
        ) return false;

        /* Check USDC and USDT blacklists */
        return IBlacklist(0xaf88d065e77c8cC2239327C5EDb3A432268e5831).isBlacklisted(account)
            || IBlacklist(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9).isBlocked(account);
    }
```

### What the code does vs. what the report claims
The code attempts to call `isBlacklisted(address)` on USDC and `isBlocked(address)` on USDT.
- **USDC (Arbitrum):** Supports `isBlacklisted(address)`.
- **USDT (Arbitrum):** Does **NOT** support `isBlocked(address)` or `isBlacklisted(address)`.

In Solidity, a high-level call to a non-existent function on a contract that contains code (like the USDT contract) will trigger a revert. Since `isBlacklisted` is called within `_update` (invoked by `transfer`, `mint`, and `burn`), any failure in this check prevents any token movement.

Verification via manual RPC call to Arbitrum Mainnet:
- Calling `isBlocked(address)` (selector `0xabbbf08a`) on `0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9` returns `{"code":3,"message":"execution reverted","data":"0x"}`.

## E2E Proof of Concept (PoC)

**File:** `test/AuditPoC.t.sol`
```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {BaseTest} from "./Base.t.sol";

contract AuditPoC is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_PermanentDoS_TransferReverts() public {
        deal(address(usdai), users.normalUser1, 1000 ether);
        vm.startPrank(users.normalUser1);

        // This will revert because it calls USDT.isBlocked() which doesn't exist on Arbitrum
        vm.expectRevert();
        usdai.transfer(address(users.normalUser2), 100 ether);

        vm.stopPrank();
    }
}
```

**Run command:** `forge test --fork-url https://arb1.arbitrum.io/rpc --match-contract AuditPoC`

## Analysis
The report is **correct**. The protocol is currently in a state of total failure on Arbitrum.

### Severity: Critical
- **Likelihood:** **High** (Triggered by any standard protocol interaction).
- **Impact:** **Critical** (Permanent loss of access to funds and protocol functionality).
- **Justification:** Every `USDai` transfer, deposit, and withdrawal is blocked. Since `StakedUSDai` and `OUSDaiUtility` rely on these operations, the entire ecosystem is frozen.

## Recommended Action
**Report immediately.**

### Fix Recommendation
Use a `try/catch` block or a low-level `staticcall` when querying external contracts that may not implement the expected interface.

```solidity
    function isBlacklisted(address account) public view returns (bool) {
        if (_getBlacklistStorage().blacklist[account]) return true;
        if (block.chainid != 42161) return false;
        if (account == 0x0B2b2B2076d95dda7817e785989fE353fe955ef9 || account == 0x24a92E28a8C5D8812DcfAf44bCb20CC0BaBd1392) return false;

        // Safely check USDC
        try IBlacklist(0xaf88d065e77c8cC2239327C5EDb3A432268e5831).isBlacklisted(account) returns (bool blacklisted) {
            if (blacklisted) return true;
        } catch {}

        // Safely check USDT
        try IBlacklist(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9).isBlocked(account) returns (bool blocked) {
            if (blocked) return true;
        } catch {}

        return false;
    }
```
