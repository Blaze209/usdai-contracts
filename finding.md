VERDICT: VULNERABLE
Confidence: HIGH
Summary: The `LoanRouter` contract accumulates trapped currency token "dust" during loan repayments because the total amount collected from the borrower is rounded up, while individual distributions to lenders are rounded down.

### Evidence
**Code location:** `lib/usdai-loan-router-contracts/src/LoanRouter.sol:930`, `lib/usdai-loan-router-contracts/src/LoanRouter.sol:519-521`

In `repay()`, the contract calculates the total `repayment` amount to pull from the borrower by rounding up to the currency token's decimals:
```solidity
// Line 930
uint256 repayment = _unscale(principalPayment + interestPayment + prepayment, true);
```
However, in the internal `_repayLenders()` function, the amounts distributed to each tranche owner are rounded down:
```solidity
// Lines 519-521
uint256 principal = _unscale(tranchePrincipals[i]);
uint256 interest = _unscale(trancheInterests[i]);
uint256 prepayment = _unscale(tranchePrepayment);
```
In multi-tranche loans, the sum of these floor-rounded values is frequently less than the ceiling-rounded total pulled from the borrower. Since the `LoanRouter` has no sweep mechanism, these funds are permanently trapped.

### E2E PoC
**File:** `test/RoundingPoC.t.sol`
**Run command:** `forge test --match-contract RoundingPoC -vvv`

**Expected output:**
```text
[PASS] testRoundingDust() (gas: 828871)
Logs:
  Loan originated
  Quote - Principal: 83333334, Interest: 259200000000000, Fees: 0
  Router balance before repay: 0
  Router balance after repay: 2
  VULNERABILITY CONFIRMED: Dust trapped in Router: 2
```

### Analysis
The asymmetric rounding logic creates a state leak where small amounts of capital (dust) are separated from the protocol's accounting and the lenders' balances.

**Severity: Low**
*   **Likelihood: High** - Occurs on almost every repayment for loans with multiple tranches or specific interest amounts.
*   **Impact: Low** - The loss per transaction is negligible (typically 1-2 units of the smallest currency denomination, e.g., $0.000002 USDC), but it is a permanent accumulation of stuck funds.

**Justification:** While the financial impact is minimal, it represents a breach of the invariant that all funds entering the `LoanRouter` for repayment should be distributable to lenders or the fee recipient.

### Recommended Action
**Report immediately.**
**Fix recommendation:** Modify `_repayLenders` to calculate the total unscaled amount that *should* be distributed (based on the `repayment` amount pulled in `repay()`) and assign any rounding remainder to one of the tranches (e.g., the first or last).

```solidity
// Suggested fix logic in _repayLenders
uint256 totalDistributed;
for (uint8 i; i < loanTerms.trancheSpecs.length; i++) {
    // ... calculations ...
    if (i == loanTerms.trancheSpecs.length - 1) {
        repayment = totalRepaymentAmountToDistribute - totalDistributed;
    }
    // ... transfer ...
    totalDistributed += repayment;
}
```

---
**Other Contracts Evaluated:**
*   `DepositTimelock.sol`: **NOT VULNERABLE**. Correct access controls and state management. Non-transferability of receipt tokens is intentional.
*   `BundleCollateralWrapper.sol`: **NOT VULNERABLE**. Secure context-based bundling logic.
*   `USDaiSwapAdapter.sol` / `UniswapV3SwapAdapter.sol`: **NOT VULNERABLE**. Correct handling of exact output swaps and refunds.
