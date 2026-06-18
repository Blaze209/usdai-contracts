// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUSDai} from "./IUSDai.sol";

/**
 * @title Base token yield escrow interface
 * @author MetaStreet Foundation
 */
interface IBaseYieldEscrow {
    /*------------------------------------------------------------------------*/
    /* Events */
    /*------------------------------------------------------------------------*/

    /**
     * @notice Deposited event
     * @param caller Caller
     * @param amount Amount
     */
    event Deposited(address indexed caller, uint256 amount);

    /**
     * @notice Withdrawn event
     * @param caller Caller
     * @param amount Amount
     */
    event Withdrawn(address indexed caller, uint256 amount);

    /**
     * @notice Harvested event
     * @param caller Caller
     * @param amount Amount
     */
    event Harvested(address indexed caller, uint256 amount);

    /**
     * @notice Base yield rate tiers set event
     * @param rateTiers Rate tiers
     */
    event BaseYieldRateTiersSet(IUSDai.RateTier[] rateTiers);

    /*------------------------------------------------------------------------*/
    /* Getter */
    /*------------------------------------------------------------------------*/

    /**
     * @notice Base token
     * @return Base Token
     */
    function baseToken() external view returns (address);

    /**
     * @notice Balance
     * @return Base token balance
     */
    function balance() external view returns (uint256);

    /*------------------------------------------------------------------------*/
    /* Permissioned API */
    /*------------------------------------------------------------------------*/

    /**
     * @notice Deposit base token
     * @param amount Base token amount
     */
    function deposit(
        uint256 amount
    ) external;

    /**
     * @notice Withdraw base token
     * @param amount Base token amount
     */
    function withdraw(
        uint256 amount
    ) external;

    /**
     * @notice Harvest base token
     * @param amount Base token amount
     */
    function harvest(
        uint256 amount
    ) external;

    /**
     * @notice Set base yield rates
     * @param rateTiers Rate tiers
     */
    function setRateTiers(
        IUSDai.RateTier[] memory rateTiers
    ) external;
}
