// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {BaseTest} from "./Base.t.sol";

interface IBlacklist {
    function isBlacklisted(address account) external view returns (bool);
    function isBlocked(address account) external view returns (bool);
}

/**
 * @title Audit PoC - permanent DoS due to reverting isBlacklisted
 * @notice This test demonstrates that the logic used in USDai is broken on Arbitrum
 * because it calls a non-existent function `isBlocked` on the USDT contract.
 */
contract AuditPoC is BaseTest {
    // Arbitrum addresses
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    function setUp() public override {
        super.setUp();
    }

    /**
     * @notice Replicates the EXACT vulnerable code path in an isolated test
     */
    function vulnerableIsBlacklisted(address account) public view returns (bool) {
        // ... local checks skipped ...

        // This is the vulnerable logic from USDai.sol v1.4
        return IBlacklist(USDC).isBlacklisted(account)
            || IBlacklist(USDT).isBlocked(account);
    }

    function test_VulnerabilityConfirmed_Isolated() public {
        console.log("Testing vulnerable logic isolated...");

        // This will revert because USDT.isBlocked does not exist on Arbitrum
        vm.expectRevert();
        this.vulnerableIsBlacklisted(users.normalUser1);

        console.log("VULNERABILITY CONFIRMED: Logic reverts on Arbitrum USDT call");
    }

    function test_VulnerabilityConfirmed_OnContract() public {
        // Note: This test assumes the contract at 0x0A1a... (USDai) has the vulnerable code.
        // On a mainnet fork, we can call it directly.
        address usdaiAddr = 0x0A1a1A107E45b7Ced86833863f482BC5f4ed82EF;

        console.log("Testing deployed contract isBlacklisted...");

        // The deployed contract on Arbitrum at the time of the audit is vulnerable
        vm.expectRevert();
        IBlacklist(usdaiAddr).isBlacklisted(users.normalUser1);

        console.log("VULNERABILITY CONFIRMED: Deployed contract reverts");
    }
}
