// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

contract UniswapV3AddLiquidity is IERC721Receiver {
    INonfungiblePositionManager public positionManager;

    constructor(address _positionManager) {
        positionManager = INonfungiblePositionManager(_positionManager);
    }

    function addLiquidity(
        address poolAddress,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 width // width = (upperPrice - lowerPrice) * 10000 / (lowerPrice + upperPrice)
    ) external {
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0(); // Fetch current price from pool
        
        (uint160 lowerPrice, uint160 upperPrice) = _calculatePrices(sqrtPriceX96, width);
        uint24 fee = pool.fee();

        // Approve tokens for position manager
        IERC20(pool.token0()).approve(address(positionManager), amount0Desired);
        IERC20(pool.token1()).approve(address(positionManager), amount1Desired);

        // Add liquidity to Uniswap V3 pool
        INonfungiblePositionManager.MintParams memory params = 
            INonfungiblePositionManager.MintParams({
                token0: pool.token0(),
                token1: pool.token1(),
                fee: fee,
                tickLower: TickMath.getTickAtSqrtRatio(lowerPrice),
                tickUpper: TickMath.getTickAtSqrtRatio(upperPrice),
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: msg.sender, // address(this)
                deadline: block.timestamp + 120
            });

        positionManager.mint(params);
    }

    function _calculatePrices(uint160 currentPrice, uint256 width) internal pure returns (uint160 lowerPrice, uint160 upperPrice) {
        // width / 10**4 = (upperPrice - lowerPrice) / (lowerPrice + upperPrice)
        // price = 1.0001**tick
        // 1.0001 = 10001 / 10000
        // upperPrice = p2, lowerPrice = p1
        // upperTick = t2, lowerTick = p1
        // p2 = 1.00001**t2, p1 = 1.00001**t1
        // w = width / 10**4
        // p = currentPrice
        // w = (p2 - p1) / (p2 + p1) // divide by p2
        // w = (p2 / p1 - 1) / (p2 / p1 + 1)
        // x = p2 / p1
        // w = (x - 1) / (x + 1)  => x = (w + 1) / (1 - w)
        // p2 = p1 * (w + 1) / (1 - w)
        // z = (w + 1) / (1 - w)
        // p = (p1 + p2) / 2
        // p1 = 2 * p - p2
        // p2 = (2 * p - p2) * z
        // p2 * (1 + z) = 2 * p * z
        // p2 = 2 * p * z / (1 + z) = 2 * p * ((w + 1) / (1 - w)) / (1 + ((w + 1) / (1 - w)))
        // p2 = 2 * p * (w + 1) / (1 - w + w + 1) = p * (w + 1)
        
        uint256 halfWidth = (width * currentPrice) / 20000; // width = (upperPrice - lowerPrice) * 10000 / (upperPrice + lowerPrice)
        lowerPrice = uint160(currentPrice - halfWidth);
        upperPrice = uint160(currentPrice + halfWidth);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
