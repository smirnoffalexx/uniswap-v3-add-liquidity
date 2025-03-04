# UniswapV3 LP providing connector with custom logic

Connector allows providing liquidity to UniswapV3 protocol. Connector accepts `token0Amount`, `token1Amount`, `poolAddress`, `width`. Where `width = (priceH - priceL) * 10^4 / (priceH + priceL)`. Connector allows to invest the desired amounts of tokens into a pool, with setting such a price range, which sattisfies the `width` condition.

## Solution

Let`s start with the basic idea: to provide liquidity in form of the required specific amounts we have to calculate the price range. Uniswap math formulas describe the liquidity deltas incoming to the pool by adding one asset only.

1. `L_x = dx * (sqrt(P) * sqrt(P_b)) / (sqrt(P_b) - sqrt(P))`
2. `L_y = dy / (sqrt(P) - sqrt(P_a))`

where:
`y` - token0.
`x` - token1.
`L_y` - liquidity delta for token0.
`L_x` - liquidity delta for token1.
`dy` - amount delta of token0.
`dx` - amount delta of token1.
`P` – spot price.
`P_a` and `P_b` – lower and upper prices (of the range).

According to the task:
3. `width = (P_b - P_a) * 10^4 / (P_b + P_a)`
<=> `P_b = (10^4 + width) * P_a / (10^4 - width)`

Let's assume `width != 0` and `width < 10^4`, otherwise price range becomes infinite or empty.

According to UniswapV3 logic the liquidity input must be done in such a way that: `L_x == L_y`. Taking into consideration all above equations we can make a system of equations and solve it againts `P_a` (for ex.).

Let's name `t = sqrt((10^4 + width)/ (10^4 - width))` for simplified calculations.
Uniswap V3 does not operate with prices, it uses `sqrtPriceX96` notation instead. Let's rename `sP = sqrt(P)` for all prices above. The resulting quadratic equation will look like this:
4. `(dx * sP * t) (P_a)^2 + t(dy - dx * (sP)^2) * P_a - dY * P = 0`
5. `P_b = t^2 * P_a`

We can divide both sides of the equation by Q96 to avoid overflow during calculations (however it will increase inaccuracy).
After all tick calculations we must make sure that ticks fulfill the `tickSpacing` requirement (`tick % tickSpacing == 0`).

**NOTE** This approach can not be 100% accurate in terms of added amounts, it is recommended to move all calculations off-chain for better accuracy and gas-efficiency. To make sure that the transaction will not fail, the connector has a possibility to set the `add liquidity acuracy` (aka to add amounts with a certain % precision).

## Implementation
Using `Hardhat` framework with `EthersV6` under the hood. Solidity version is `0.8.27`, `UniswapV3` protocol is not cloned entirely, simply using the npm packages with interfaces and libraries. Tests are being executed on a fork.

The curent solution is in the `contracts/UniswapV3Connector.sol` file.
Tests are in the `test/Connector.test.ts` file.

Unfortunatelly, I did not have enough time to impelent a full coverage, but tests implement a basic scenatio with prices calculations for a real `BTCB / USDT` pool. Tests are executed on a `BNB Chain` fork. Deployment fixtures are used for a quicker tests setup during execution.

**TO BE DONE** more tests, 100% coverage, deploy to mainnet.

## Setup 

Node v18 or newer is required for operation.
```shell
$ yarn
cp .env.example .env
```

Paste your `BNB Rpc Url` into the `RPC_BSC_MAIN` env variable in the `.env` file. Otherwise fork tests will fail. Notice that after the latest update of Hardhat not all nodes can be used for forking (it is recomended to use Tenderly, Alchemy or Infura private urls).

### Build

```shell
$ yarn compile
```

### Test

```shell
$ yarn test
```