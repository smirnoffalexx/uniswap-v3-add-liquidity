import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers'
import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers'
import { ethers } from 'hardhat'
import {
  ERC20,
  INonfungiblePositionManager,
  IUniswapV3Factory,
  IUniswapV3Pool,
  UniswapV2Router02,
  UniswapV3Connector,
  UniswapV3Connector__factory,
} from '../typechain-types'
import { deployDefaultFixture } from './index'
import { ADDRESSES, epsEqual, randomAddress, sqrt, toPrice } from './helper'
import { expect } from 'chai'

describe('UniswapV3Connector', function () {
  let deployer: SignerWithAddress
  let user0: SignerWithAddress
  let user1: SignerWithAddress
  let uniswapConnectorFactory: UniswapV3Connector__factory
  let connector: UniswapV3Connector
  let pool: IUniswapV3Pool
  let posManager: INonfungiblePositionManager
  let factory: IUniswapV3Factory
  let btcb: ERC20
  let usdt: ERC20
  let fee = 5_00n // 0.05%
  let uniswapV2Router: UniswapV2Router02

  const ONE = ethers.WeiPerEther
  const Q96 = 2n ** 96n

  beforeEach(async () => {
    const state = await loadFixture(deployDefaultFixture)

    deployer = state.signers[0]
    user0 = state.signers[1]
    user1 = state.signers[2]

    uniswapConnectorFactory = state.uniswapConnectorFactory
    connector = state.connector

    factory = await ethers.getContractAt('IUniswapV3Factory', ADDRESSES.uniV3Factory)
    posManager = await ethers.getContractAt(
      'INonfungiblePositionManager',
      ADDRESSES.uniV3PositionManager
    )

    uniswapV2Router = await ethers.getContractAt(
      'UniswapV2Router02',
      ADDRESSES.uniV2Router
    )

    btcb = await ethers.getContractAt('ERC20', ADDRESSES.btcb)
    usdt = await ethers.getContractAt('ERC20', ADDRESSES.usdt)

    pool = await ethers.getContractAt(
      'IUniswapV3Pool',
      await factory.getPool(btcb.target, usdt.target, fee)
    )

    await uniswapV2Router
      .connect(deployer)
      .swapExactETHForTokens(
        0n,
        [await uniswapV2Router.WETH(), await btcb.getAddress()],
        deployer.address,
        10n ** 10n,
        {
          value: ONE * 1_000n,
        }
      )

    await uniswapV2Router
      .connect(deployer)
      .swapExactETHForTokens(
        0n,
        [await uniswapV2Router.WETH(), await usdt.getAddress()],
        deployer.address,
        10n ** 10n,
        {
          value: ONE * 10n,
        }
      )

    expect(await btcb.balanceOf(deployer.address)).gt(0)
    expect(await usdt.balanceOf(deployer.address)).gt(0)
  })

  it('calculates prices higher and lower for amounts', async () => {
    const [sqrtPriceX96, tick] = await pool.slot0()

    let token0In = ONE
    let token1In = ONE

    const width = 5000n

    const res = await connector.calculateTicks(sqrtPriceX96, token0In, token1In, width)

    // const price = toPrice(sqrtPriceX96).invertedPrice // ===> current BTC price :)

    // check prices
    const priceLower = toPrice(res.sqrtPriceX96Lower).invertedPrice
    const priceUpper = toPrice(res.sqrtPriceX96Upper).invertedPrice

    const expectedWidth =
      ((priceUpper - priceLower) * 10_000n) / (priceUpper + priceLower)

    // expectedWidth ~= width
    // compare with accuracy 0.1%
    expect(epsEqual(expectedWidth, width)).true

    // check that price range strictly includes the current price
    expect(res.sqrtPriceX96Lower).lt(sqrtPriceX96)
    expect(sqrtPriceX96).lt(res.sqrtPriceX96Upper)
  })
})
