// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {USDai} from "src/USDai.sol";
import {StakedUSDai} from "src/StakedUSDai.sol";
import {BaseYieldEscrow} from "src/BaseYieldEscrow.sol";
import {ChainlinkPriceOracle} from "src/oracles/ChainlinkPriceOracle.sol";
import {UniswapV3SwapAdapter} from "src/swapAdapters/UniswapV3SwapAdapter.sol";

import {IUSDai} from "src/interfaces/IUSDai.sol";
import {IStakedUSDai} from "src/interfaces/IStakedUSDai.sol";
import {ILoanRouterPositionManager} from "src/interfaces/ILoanRouterPositionManager.sol";

/**
 * @title Base token upgrade test
 * @author MetaStreet Foundation
 */
contract BaseTokenUpgradeTest is Test {
    /*------------------------------------------------------------------------*/
    /* Constants */
    /*------------------------------------------------------------------------*/

    address internal constant PROXY_ADMIN = 0x783B08aA21DE056717173f72E04Be0E91328A07b;

    /* Arbitrum Mainnet addresses */
    address internal constant PYUSD = 0x46850aD61C2B7d64d08c9C754F45254596696984;
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant USDAI = 0x0A1a1A107E45b7Ced86833863f482BC5f4ed82EF;
    address internal constant STAKED_USDAI = 0x0B2b2B2076d95dda7817e785989fE353fe955ef9;
    address internal constant WRAPPED_M_TOKEN = 0x437cc33344a0B27A429f795ff6B469C72698B291;
    address internal constant LOAN_ROUTER = 0x0C2ED170F2bB1DF1a44292Ad621B577b3C9597D1;
    address internal constant USDC_PRICE_FEED = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;
    address internal constant ADMIN_FEE_RECIPIENT = 0x5F0BC72FB5952b2f3F2E11404398eD507B25841F;
    address internal constant ADMIN = 0x5F0BC72FB5952b2f3F2E11404398eD507B25841F;
    address internal constant UNISWAP_V3_SWAP_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address internal constant PYUSD_PRICE_FEED = 0x3d50d699A812A0f66F36876DF47B2aE68e781736;

    /* Admin fee rate for loan router (10%) */
    uint256 internal constant LOAN_ROUTER_ADMIN_FEE_RATE = 1000; // 10% in basis points

    /* Base yield admin fee rate (10%) */
    uint256 internal constant BASE_YIELD_ADMIN_FEE_RATE = 1000; // 10% in basis points

    /* Base yield escrow */
    address internal baseYieldEscrow;

    /* Price oracle */
    address internal priceOracle;

    /* Uniswap V3 swap adapter */
    address internal uniswapV3SwapAdapter;

    /*------------------------------------------------------------------------*/
    /* Setup */
    /*------------------------------------------------------------------------*/

    function setUp() public {
        // Fork Arbitrum mainnet
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        vm.rollFork(426257307);

        deployBaseYieldEscrow();
        deployPriceOracle();
        deployUniswapV3SwapAdapter();
    }

    /*------------------------------------------------------------------------*/
    /* Deploy functions */
    /*------------------------------------------------------------------------*/

    function deployBaseYieldEscrow() internal {
        /* Deploy base token yield escrow */
        BaseYieldEscrow baseYieldEscrowImpl = new BaseYieldEscrow(USDAI, PYUSD);
        TransparentUpgradeableProxy baseYieldEscrowProxy = new TransparentUpgradeableProxy(
            address(baseYieldEscrowImpl), address(ADMIN), abi.encodeWithSignature("initialize(address)", ADMIN)
        );
        baseYieldEscrow = address(baseYieldEscrowProxy);

        /* Grant roles */
        vm.prank(ADMIN);
        AccessControl(baseYieldEscrow).grantRole(keccak256("ESCROW_ADMIN_ROLE"), ADMIN);
    }

    function deployPriceOracle() internal {
        address[] memory tokens = new address[](1);
        tokens[0] = USDC;

        address[] memory priceFeeds = new address[](1);
        priceFeeds[0] = USDC_PRICE_FEED;

        /* Deploy price oracle */
        priceOracle = address(new ChainlinkPriceOracle(PYUSD_PRICE_FEED, tokens, priceFeeds, ADMIN));
    }

    function deployUniswapV3SwapAdapter() internal {
        address[] memory tokens = new address[](1);
        tokens[0] = USDC;

        /* Deploy uniswap v3 swap adapter */
        uniswapV3SwapAdapter = address(new UniswapV3SwapAdapter(PYUSD, UNISWAP_V3_SWAP_ROUTER, tokens));
    }

    /*------------------------------------------------------------------------*/
    /* Upgrade functions */
    /*------------------------------------------------------------------------*/

    function upgradeUSDai() internal {
        // Get proxy admin from EIP-1967 storage slot
        address proxyAdminAddress =
            address(uint160(uint256(vm.load(USDAI, bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)))));

        // Deploy new implementation with LoanRouterPositionManager
        USDai usdaiImpl = new USDai(uniswapV3SwapAdapter, baseYieldEscrow, STAKED_USDAI);

        // Upgrade proxy using ProxyAdmin interface
        vm.prank(PROXY_ADMIN);
        ProxyAdmin(proxyAdminAddress).upgradeAndCall(ITransparentUpgradeableProxy(USDAI), address(usdaiImpl), "");
    }

    function upgradeStakedUSDai() internal {
        // Get proxy admin from EIP-1967 storage slot
        address proxyAdminAddress =
            address(uint160(uint256(vm.load(STAKED_USDAI, bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)))));

        // Deploy new implementation with LoanRouterPositionManager
        StakedUSDai stakedUsdaiImpl = new StakedUSDai(
            USDAI,
            WRAPPED_M_TOKEN,
            address(priceOracle),
            LOAN_ROUTER,
            ADMIN_FEE_RECIPIENT,
            uint64(block.timestamp),
            BASE_YIELD_ADMIN_FEE_RATE,
            LOAN_ROUTER_ADMIN_FEE_RATE
        );

        // Upgrade proxy using ProxyAdmin interface
        vm.prank(PROXY_ADMIN);
        ProxyAdmin(proxyAdminAddress).upgradeAndCall(
            ITransparentUpgradeableProxy(STAKED_USDAI),
            address(stakedUsdaiImpl),
            abi.encodeWithSelector(StakedUSDai.migrate.selector)
        );
    }

    /*------------------------------------------------------------------------*/
    /* Test Upgrade */
    /*------------------------------------------------------------------------*/

    function test__RepaymentBalanceMigration() public {
        IUSDai usdai = IUSDai(USDAI);
        IStakedUSDai stakedUsdai = IStakedUSDai(STAKED_USDAI);

        // Get before state
        uint256 usdaiTotalSupplyBefore = usdai.totalSupply();
        uint256 usdaiTotalBridgedSupplyBefore = usdai.bridgedSupply();

        uint256 navBefore = stakedUsdai.nav();
        uint256 redemptionSharePriceBefore = stakedUsdai.redemptionSharePrice();
        uint256 depositSharePriceBefore = stakedUsdai.depositSharePrice();
        (uint256 repaymentBefore,,) = ILoanRouterPositionManager(address(stakedUsdai)).loanRouterBalances();

        // Upgrade
        upgradeUSDai();
        upgradeStakedUSDai();

        (uint256 repaymentAfter,,) = ILoanRouterPositionManager(address(stakedUsdai)).loanRouterBalances();
        (uint256 usdcBalanceAfter, uint256 usdcAdminFeeAfter) =
            ILoanRouterPositionManager(address(stakedUsdai)).repaymentBalances(USDC);

        // Verify staked USDai
        assertGt(stakedUsdai.nav(), navBefore, "Nav should be larger");
        assertGt(
            stakedUsdai.redemptionSharePrice(), redemptionSharePriceBefore, "Redemption share price should be larger"
        );
        assertGt(stakedUsdai.depositSharePrice(), depositSharePriceBefore, "Deposit share price should be larger");
        assertGt(repaymentAfter, repaymentBefore, "Repayment balance should be larger");
        assertEq(
            IERC20(USDC).balanceOf(address(stakedUsdai)),
            usdcBalanceAfter + usdcAdminFeeAfter,
            "USDC balance should be larger"
        );
    }

    function createUser(
        string memory name
    ) internal returns (address payable addr) {
        addr = payable(makeAddr(name));
        vm.label({account: addr, newLabel: name});
        vm.deal({account: addr, newBalance: 100 ether});
    }
}
