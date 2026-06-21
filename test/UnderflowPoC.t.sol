// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {USDai} from "src/USDai.sol";
import {StakedUSDai} from "src/StakedUSDai.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockBaseToken is ERC20 {
    constructor() ERC20("Mock Base", "MB") {}
    function mint(address to, uint256 amount) public { _mint(to, amount); }
    function decimals() public pure override returns (uint8) { return 6; }
}

contract MockSwapAdapter {
    address public baseToken;
    constructor(address _baseToken) { baseToken = _baseToken; }
    function swapIn(address, uint256, uint256, bytes calldata) external pure returns (uint256) { return 0; }
}

contract MockLoanRouter {
    function depositTimelock() external pure returns (address) { return address(0x42); }
}

contract UnderflowPoCTest is Test {
    USDai usdai;
    StakedUSDai stakedUsdai;
    MockBaseToken baseToken;
    MockSwapAdapter swapAdapter;
    MockLoanRouter loanRouter;

    address admin = address(0x1);
    address bridgeAdapter = address(0x2);
    address user = address(0x3);

    function setUp() public {
        baseToken = new MockBaseToken();
        swapAdapter = new MockSwapAdapter(address(baseToken));
        loanRouter = new MockLoanRouter();

        // Deploy USDai
        USDai usdaiImpl = new USDai(address(swapAdapter), address(0), address(0), bridgeAdapter);
        TransparentUpgradeableProxy usdaiProxy = new TransparentUpgradeableProxy(
            address(usdaiImpl), admin, abi.encodeWithSignature("initialize(address)", admin)
        );
        usdai = USDai(address(usdaiProxy));

        // Deploy StakedUSDai
        StakedUSDai stakedUsdaiImpl = new StakedUSDai(
            address(usdai),
            address(0),
            address(loanRouter),
            address(0),
            uint64(block.timestamp),
            0,
            0,
            bridgeAdapter
        );
        TransparentUpgradeableProxy stakedUsdaiProxy = new TransparentUpgradeableProxy(
            address(stakedUsdaiImpl), admin, abi.encodeWithSignature("initialize(address)", admin)
        );
        stakedUsdai = StakedUSDai(address(stakedUsdaiProxy));
    }

    function test_USDai_Mint_Underflow() public {
        vm.prank(bridgeAdapter);
        // This will attempt to do _getSupplyStorage().bridged -= 100 ether
        // Since bridged is 0, it will underflow and revert
        vm.expectRevert();
        usdai.mint(user, 100 ether);
    }

    function test_StakedUSDai_Mint_Underflow() public {
        vm.prank(bridgeAdapter);
        // This will attempt to do _getBridgedSupplyStorage().bridgedSupply -= 100 ether
        // Since bridgedSupply is 0, it will underflow and revert
        vm.expectRevert();
        stakedUsdai.mint(user, 100 ether);
    }
}
