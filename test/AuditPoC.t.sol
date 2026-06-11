// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {BaseTest} from "./Base.t.sol";

/**
 * @title Audit PoC - permanent DoS due to reverting isBlacklisted
 * @notice This test demonstrates that the USDai contract is permanently broken on Arbitrum
 * because it calls a non-existent function `isBlocked` on the USDT contract.
 */
contract AuditPoC is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_PermanentDoS_TransferReverts() public {
        // Normal user has some USDai (via deal)
        deal(address(usdai), users.normalUser1, 1000 ether);

        vm.startPrank(users.normalUser1);

        // This transfer should normally succeed, but it will revert because:
        // 1. _update calls isBlacklisted(users.normalUser1)
        // 2. isBlacklisted(users.normalUser1) calls USDT.isBlocked(users.normalUser1)
        // 3. USDT on Arbitrum does not have isBlocked(address) and reverts.

        console.log("Attempting to transfer USDai...");

        // Expect revert due to the missing function call in the blacklist check
        vm.expectRevert();
        usdai.transfer(address(users.normalUser2), 100 ether);

        console.log("Transfer reverted as expected.");
        vm.stopPrank();
    }
}
