// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "balancer-v2-monorepo/pkg/interfaces/contracts/vault/IVault.sol";
import {ISwapRouter} from "../../src/interfaces/ISwapRouter.sol";

import {Test, console2} from "forge-std/Test.sol";
import {stETHLeverage} from "../../src/stETHLeverage.sol";

contract stETHLeverageForkTest is Test {
    address balancer = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address aave = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address vWeth = 0xeA51d7853EEFb32b6ee06b1C12E6dcCA88Be0fFE;
    address univ3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address owner = makeAddr("owner");
    stETHLeverage leverage;

    function setUp() public {
        string memory MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(forkId);
        vm.rollFork(19040344);
        vm.deal(owner, 10 ether);
        vm.prank(owner);
        leverage = new stETHLeverage(aave, balancer, wstETH, weth, vWeth, univ3Router);
    }

    function testOpenPosition() public {
        vm.prank(owner);
        leverage.openPosition{value: 2 ether}(5 ether);
    }

    function testClosePosition() public {
        testOpenPosition();
        vm.prank(owner);
        leverage.closePosition(1);
    }

    function testLeverageBringsGreaterProfit() public {
        uint256 snapshot = vm.snapshot();
        testOpenPosition();
        vm.startPrank(owner);

        vm.rollFork(19340344);

        leverage.closePosition(1);
        uint256 leverageStakeBalance = owner.balance;

        vm.revertTo(snapshot);
        wstETH.call{value: 2 ether}("");
        vm.rollFork(19340344);
        IERC20(wstETH).approve(univ3Router, type(uint256).max);
        uint256 balance = IERC20(wstETH).balanceOf(owner);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: wstETH,
            tokenOut: weth,
            fee: 100,
            recipient: owner,
            deadline: block.timestamp,
            amountIn: balance,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        uint256 amountOut = ISwapRouter(univ3Router).exactInputSingle(params);
        IWETH(weth).withdraw(amountOut);
        uint256 normalStakeBalance = owner.balance;

        vm.stopPrank();
        assertGt(leverageStakeBalance, normalStakeBalance);
    }
}
