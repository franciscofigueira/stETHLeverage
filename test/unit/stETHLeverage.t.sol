// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "balancer-v2-monorepo/pkg/interfaces/contracts/vault/IVault.sol";
import {ISwapRouter} from "../../src/interfaces/ISwapRouter.sol";

import {Test, console2} from "forge-std/Test.sol";
import {stETHLeverage} from "../../src/stETHLeverage.sol";

contract stETHLeverageTest is Test {
    address constant ZERO = address(0);
    address owner = makeAddr("owner");
    stETHLeverage leverage;

    function setUp() public {
        vm.deal(owner, 10 ether);
        vm.prank(owner);
        leverage = new stETHLeverage(ZERO, ZERO, ZERO, ZERO, ZERO, ZERO);
    }

    function testOnlyOnwer() public {
        address attacker = makeAddr("attacker");

        vm.expectRevert(abi.encodeWithSelector(stETHLeverage.stETHLeverage__OnlyOwner.selector, owner, attacker));
        vm.prank(attacker);
        leverage.openPosition(2);

        vm.expectRevert(abi.encodeWithSelector(stETHLeverage.stETHLeverage__OnlyOwner.selector, owner, attacker));
        vm.prank(attacker);
        leverage.closePosition(2);
    }

    function testOnlyBlancer() public {
        address attacker = makeAddr("attacker");

        IERC20[] memory tokens;
        uint256[] memory amounts;
        vm.expectRevert(abi.encodeWithSelector(stETHLeverage.stETHLeverage__OnlyBalancer.selector, ZERO, attacker));

        vm.prank(attacker);
        leverage.receiveFlashLoan(tokens, amounts, amounts, "");
    }
}
