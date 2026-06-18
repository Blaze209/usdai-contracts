// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Base Position Manager Interface
 * @author MetaStreet Foundation
 */
interface IBasePositionManager {
    /*------------------------------------------------------------------------*/
    /* Events */
    /*------------------------------------------------------------------------*/

    /**
     * @notice Base yield deposited
     * @param depositedAmount Deposited USDai amount
     * @param adminFee Admin fee
     */
    event BaseYieldDeposited(uint256 depositedAmount, uint256 adminFee);

    /**
     * @notice Base yield harvested
     * @param harvestedAmount Harvested USDai amount
     * @param adminFee Admin fee
     */
    event BaseYieldHarvested(uint256 harvestedAmount, uint256 adminFee);

    /*------------------------------------------------------------------------*/
    /* Getter */
    /*------------------------------------------------------------------------*/

    /**
     * @notice Claimable base yield in USDai
     * @return Claimable base yield in USDai
     */
    function claimableBaseYield() external view returns (uint256);

    /*------------------------------------------------------------------------*/
    /* Permissioned API */
    /*------------------------------------------------------------------------*/

    /**
     * @notice Harvest base yield
     * @return Harvested USDai amount
     * @return Admin fee
     */
    function harvestBaseYield() external returns (uint256, uint256);

    /**
     * @notice Deposit base yield
     * @param usdaiAmount USDai amount
     * @param usdaiAmountMinimum Minimum USDai amount
     * @param swapData Swap data
     * @return Deposited USDai amount
     * @return Admin fee
     */
    function depositBaseYield(
        uint256 usdaiAmount,
        uint256 usdaiAmountMinimum,
        bytes calldata swapData
    ) external returns (uint256, uint256);
}
