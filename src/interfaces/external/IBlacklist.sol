// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Blacklist Interface
 * @author MetaStreet Foundation
 */
interface IBlacklist {
    /**
     * @notice Check if an address is blacklisted (USDC)
     * @param account Account
     * @return Is blacklisted
     */
    function isBlacklisted(
        address account
    ) external view returns (bool);

    /**
     * @notice Check if an address is blocked (USDT)
     * @param account Account
     * @return Is blocked
     */
    function isBlocked(
        address account
    ) external view returns (bool);
}
