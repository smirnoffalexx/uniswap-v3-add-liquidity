import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("UniswapV3AddLiquidity", function () {
  async function deployUniswapV3AddLiquidityFixture() {
    const [owner, otherAccount] = await hre.ethers.getSigners();

    const DAI = await hre.ethers.getContractAt(
      "IERC20",
      "0x6B175474E89094C44Da98b954EedeAC495271d0F"
    );
    const WETH = await hre.ethers.getContractAt(
      "IWETH",
      "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    );
    const daiWethPool = await hre.ethers.getContractAt(
      "IUniswapV3Pool",
      "0xc2e9f25be6257c210d7adf0d4cd6e3e881ba25f8"
    );
    const nonfungiblePositionManager = await hre.ethers.getContractAt(
      "INonfungiblePositionManager",
      "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"
    );
    const UniswapV3AddLiquidity = await hre.ethers.getContractFactory(
      "UniswapV3AddLiquidity"
    );
    const uniswapV3AddLiquidity = await UniswapV3AddLiquidity.deploy(
      nonfungiblePositionManager.target
    );

    return {
      uniswapV3AddLiquidity,
      nonfungiblePositionManager,
      daiWethPool,
      DAI,
      WETH,
      owner,
      otherAccount,
    };
  }

  describe("Deployment", function () {
    it("Should set the right positionManager", async function () {
      const { uniswapV3AddLiquidity, nonfungiblePositionManager } =
        await loadFixture(deployUniswapV3AddLiquidityFixture);

      expect(await uniswapV3AddLiquidity.positionManager()).to.equal(
        nonfungiblePositionManager.target
      );
    });
  });

  describe("Add liquidity", function () {
    it("Successfully mint a new position", async function () {
      const {
        uniswapV3AddLiquidity,
        nonfungiblePositionManager,
        daiWethPool,
        owner,
      } = await loadFixture(deployUniswapV3AddLiquidityFixture);
      const amount0Desired = BigInt(1000);
      const amount1Desired = BigInt(1000);
      const width = BigInt(100);
      const expectedTokenId = BigInt(1);
      const expectedLiquidity = BigInt(2);
      const expectedAmount0 = BigInt(1);
      const expectedAmount1 = BigInt(2);

      await expect(
        uniswapV3AddLiquidity.addLiquidity(
          daiWethPool.target,
          amount0Desired,
          amount1Desired,
          width
        )
      )
        .to.emit(uniswapV3AddLiquidity, "IncreaseLiquidity")
        .withArgs(
          expectedTokenId,
          expectedLiquidity,
          expectedAmount0,
          expectedAmount1
        );

      expect(
        await nonfungiblePositionManager.ownerOf(expectedTokenId)
      ).to.equal(owner.address);
    });
  });
});
