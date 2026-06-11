// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {LoanRouter} from "lib/usdai-loan-router-contracts/src/LoanRouter.sol";
import {SimpleInterestRateModel} from "lib/usdai-loan-router-contracts/src/rates/SimpleInterestRateModel.sol";
import {ILoanRouter} from "lib/usdai-loan-router-contracts/src/interfaces/ILoanRouter.sol";
import {LoanTermsLogic} from "lib/usdai-loan-router-contracts/src/LoanTermsLogic.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MockERC20 is ERC20 {
    uint8 private _decimals;
    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
    }
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract MockERC721 is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}
    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

contract RoundingPoC is Test {
    LoanRouter router;
    LoanRouter routerImpl;
    SimpleInterestRateModel model;
    MockERC20 usdc;
    MockERC721 nft;

    address admin = address(0xAD);
    address borrower = address(0xB0);
    address feeRecipient = address(0xFE);
    address proxyAdmin = address(0xDA);

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC", 6);
        nft = new MockERC721();
        model = new SimpleInterestRateModel();

        routerImpl = new LoanRouter(address(0), address(0), address(0));

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(routerImpl),
            proxyAdmin,
            abi.encodeWithSelector(LoanRouter.initialize.selector, admin, feeRecipient, 1000)
        );

        router = LoanRouter(address(proxy));
    }

    function testRoundingDust() public {
        uint256 principal = 1000 * 1e6; // 1000 USDC

        uint256 l1_key = 0x11;
        uint256 l2_key = 0x22;
        address l1 = vm.addr(l1_key);
        address l2 = vm.addr(l2_key);

        ILoanRouter.TrancheSpec[] memory tranches = new ILoanRouter.TrancheSpec[](2);
        tranches[0] = ILoanRouter.TrancheSpec({
            lender: l1,
            amount: principal / 2,
            rate: 1e17 // 10%
        });
        tranches[1] = ILoanRouter.TrancheSpec({
            lender: l2,
            amount: principal / 2,
            rate: 1e17 // 10%
        });

        ILoanRouter.LoanTerms memory terms = ILoanRouter.LoanTerms({
            expiration: uint64(block.timestamp + 1 hours),
            borrower: borrower,
            currencyToken: address(usdc),
            collateralToken: address(nft),
            collateralTokenId: 1,
            duration: 360 days,
            repaymentInterval: 30 days,
            interestRateModel: address(model),
            gracePeriodRate: 0,
            gracePeriodDuration: 0,
            feeSpec: ILoanRouter.FeeSpec({originationFee: 0, exitFee: 0}),
            trancheSpecs: tranches,
            collateralWrapperContext: "",
            options: ""
        });

        nft.mint(borrower, 1);
        usdc.mint(l1, principal / 2);
        usdc.mint(l2, principal / 2);

        vm.prank(l1); usdc.approve(address(router), type(uint256).max);
        vm.prank(l2); usdc.approve(address(router), type(uint256).max);

        vm.startPrank(borrower);
        nft.approve(address(router), 1);

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("USDai Loan Router")),
                keccak256(bytes("1.0")),
                block.chainid,
                address(router)
            )
        );

        bytes32 structHash = LoanTermsLogic.hashLoanTermsWithNonce(terms, 0);
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(l1_key, digest);
        bytes memory sig1 = abi.encodePacked(r1, s1, v1);

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(l2_key, digest);
        bytes memory sig2 = abi.encodePacked(r2, s2, v2);

        ILoanRouter.LenderDepositInfo[] memory depositInfos = new ILoanRouter.LenderDepositInfo[](2);
        depositInfos[0] = ILoanRouter.LenderDepositInfo({depositType: ILoanRouter.DepositType.ERC20Approval, data: sig1});
        depositInfos[1] = ILoanRouter.LenderDepositInfo({depositType: ILoanRouter.DepositType.ERC20Approval, data: sig2});

        router.borrow(terms, depositInfos);
        vm.stopPrank();

        console.log("Loan originated");

        // Warp to repayment window
        vm.warp(block.timestamp + 30 days);

        (uint256 p, uint256 i, uint256 f) = router.quote(terms);
        console.log("Quote - Principal: %s, Interest: %s, Fees: %s", p, i, f);

        uint256 totalRepayment = p + i + f;
        usdc.mint(borrower, totalRepayment);

        vm.startPrank(borrower);
        usdc.approve(address(router), totalRepayment);

        uint256 routerBalanceBefore = usdc.balanceOf(address(router));
        router.repay(terms, totalRepayment);
        uint256 routerBalanceAfter = usdc.balanceOf(address(router));
        vm.stopPrank();

        console.log("Router balance before repay: %s", routerBalanceBefore);
        console.log("Router balance after repay: %s", routerBalanceAfter);

        if (routerBalanceAfter > routerBalanceBefore) {
            console.log("VULNERABILITY CONFIRMED: Dust trapped in Router: %s", routerBalanceAfter - routerBalanceBefore);
        } else {
            console.log("NO VULNERABILITY: No dust trapped");
        }
    }
}
