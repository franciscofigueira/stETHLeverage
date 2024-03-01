## stETHLeverage

This repo contains a smart contract that lets the user create a leveraged position on ETH staking.

The contract is based on the approch described in [0Kage Diaries Chapter 2 — Affine](https://medium.com/@0kage/hack-series-deep-dive-chapter-2-affine-da2d7b0bbefd).

The strategy works by requesting a flashloan of WETH from [balancer](https://balancer.fi/), exchaging for [lido](https://lido.fi/) wstETH which is deposited into [AAVE](https://aave.com/). This AAVE position is then used as collateral to borrow WETH which is then used to repay the flashloan. 
With this we create a leveraged position on ETH staking that is more profitable than simplying holding wstETH, as long as the interest rate of AAVE remains lower than ETH staking rewards.

To close the position, the user requests a WETH flashloan from Balancer which is used to repay the debt on AAVE. Then we withdraw the wstETH from AAVE and swap it for WETH on UniSwapV3. The WETH is used to repay the flashloan and the profit is sent to the user.

### Usage

To install all dependencies and build the project run
``` 
make
``` 

To run tests create a `.env` file and insert a Ethereum mainnet RPC API key, in the following fashion:
```
MAINNET_RPC_URL="<YOUR_API_KEY>"
```
And then run 
``` 
forge test
```

### DISCLAIMER
**This contract has not been audited and should not be used in production. This is a an example of how a staking leveraged position can be created**
