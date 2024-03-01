// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "balancer-v2-monorepo/pkg/interfaces/contracts/vault/IVault.sol";
import "balancer-v2-monorepo/pkg/interfaces/contracts/vault/IFlashLoanRecipient.sol";
import {ISwapRouter} from "./interfaces/ISwapRouter.sol";
import {IAave} from "./interfaces/IAave.sol";

contract stETHLeverage is IFlashLoanRecipient {
    IAave immutable aaveV3Pool;
    address immutable balancer;
    address immutable wstETH;
    address immutable weth;
    address immutable vWeth;
    ISwapRouter immutable swapRouter;
    address immutable owner;

    error stETHLeverage__OnlyOwner(address want, address have);
    error stETHLeverage__OnlyBalancer(address want, address have);
    error stETHLeverage__CallFailed(bytes data);

    modifier OnlyOwner() {
        if (msg.sender != owner) {
            revert stETHLeverage__OnlyOwner(owner, msg.sender);
        }
        _;
    }

    constructor(
        address _aaveV3Pool,
        address _balancer,
        address _wstETH,
        address _weth,
        address _vWeth,
        address _swapRouter
    ) {
        aaveV3Pool = IAave(_aaveV3Pool);
        balancer = _balancer;
        wstETH = _wstETH;
        weth = _weth;
        vWeth = _vWeth;
        swapRouter = ISwapRouter(_swapRouter);
        owner = msg.sender;
    }

    function openPosition(uint256 loanAmount) external payable OnlyOwner {
        IERC20[] memory tokens = new IERC20[](1);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = loanAmount;
        tokens[0] = IERC20(weth);
        bytes memory userData = abi.encode(uint256(0));
        IVault(balancer).flashLoan(this, tokens, amounts, userData);
    }

    function closePosition(uint256 minWethOut) external OnlyOwner {
        uint256 currentDebt = IERC20(vWeth).balanceOf(address(this));
        IERC20[] memory tokens = new IERC20[](1);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = currentDebt;
        tokens[0] = IERC20(weth);
        bytes memory userData = abi.encode(minWethOut);
        IVault(balancer).flashLoan(this, tokens, amounts, userData);
    }

    function receiveFlashLoan(IERC20[] memory, uint256[] memory amounts, uint256[] memory, bytes memory userData)
        external
        override
    {
        if (msg.sender != balancer) {
            revert stETHLeverage__OnlyBalancer(balancer, msg.sender);
        }
        uint256 minWethOut = abi.decode(userData, (uint256));
        if (minWethOut == 0) _openPoisitionCallBack(amounts[0]);
        else _closePositionCallback(amounts[0], minWethOut);
    }

    function _openPoisitionCallBack(uint256 amount) internal {
        //turn weth to eth
        IWETH(weth).withdraw(amount);

        //deposit ETH and get wstETH
        (bool success, bytes memory returnData) = wstETH.call{value: address(this).balance}("");
        if (!success) {
            revert stETHLeverage__CallFailed(returnData);
        }
        uint256 wstETHBalance = IERC20(wstETH).balanceOf(address(this));

        //aaveV3Pool.setUserEMode()
        //Supply wstETH to AAVE
        IERC20(wstETH).approve(address(aaveV3Pool), wstETHBalance);
        aaveV3Pool.supply(wstETH, wstETHBalance, address(this), 0);
        //Borrow WETH from AAVE
        aaveV3Pool.borrow(weth, amount, 2, 0, address(this));
        //Repay flashLoan
        IERC20(weth).transfer(balancer, amount);
    }

    function _closePositionCallback(uint256 amount, uint256 minWethOut) internal {
        //Repay Aave debt
        IERC20(weth).approve(address(aaveV3Pool), amount);
        aaveV3Pool.repay(weth, type(uint256).max, 2, address(this));

        //withdraw from aave
        aaveV3Pool.withdraw(wstETH, type(uint256).max, address(this));
        uint256 wstEThBalance = IERC20(wstETH).balanceOf(address(this));
        //trade wsteth for weth
        IERC20(wstETH).approve(address(swapRouter), wstEThBalance);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: wstETH,
            tokenOut: weth,
            fee: 100,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: wstEThBalance,
            amountOutMinimum: minWethOut,
            sqrtPriceLimitX96: 0
        });
        uint256 amountOut = swapRouter.exactInputSingle(params);
        //repay balancer
        IERC20(weth).transfer(balancer, amount);
    }

    receive() external payable {}
}
