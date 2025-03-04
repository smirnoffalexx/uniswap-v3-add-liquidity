// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import './external/INonfungiblePositionManager.sol';
import '@openzeppelin/contracts/utils/math/Math.sol';
import './external/TickMath.sol';

/**
 * @title UniswapV3Connector
 * @author Pavel Grigoriev
 * @notice Allows to add liquidity to UniswapV3Pool.
 * @dev Contract accepts Pool address, token0 and token1 amounts, 
 * price range width = (upperPrice - lowerPrice) * 10000 / (lowerPrice + upperPrice).
 */
contract UniswapV3Connector {
    using SafeERC20 for IERC20;

    struct PoolInfo {
        uint160 sqrtPriceX96;
        uint8 feeProtocol;
        address token0;
        address token1;
        int24 tickSpacing;
    }

    uint256 public constant DENOMINATOR = 100_00;
    uint256 public constant Q96 = 2 ** 96;
    uint256 public constant Q48 = 2 ** 48;
    uint256 public constant Q24 = 2 ** 24;

    event AddedLiquidity(
        uint256 indexed tokenId,
        uint256 indexed amount0,
        uint256 indexed amount1
    );

    function addLiquidity(
        address positionManager,
        address pool,
        uint256 amount0In,
        uint256 amount1In,
        uint256 width,
        uint256 accuracyNumerator,
        uint256 deadline
    ) external returns (uint256 tokenId, uint256 amount0, uint256 amount1) {
        require(pool != address(0), 'Invalid pool');
        require(positionManager != address(0), 'Invalid manager');

        (uint256 minAmount0, uint256 minAmount1) = _getActualMinAmounts(
            amount0In,
            amount1In,
            accuracyNumerator
        );

        PoolInfo memory info = _getPoolInfo(pool);

        (int24 tickLower, int24 tickUpper, , ) = calculateTicks(
            info.sqrtPriceX96,
            amount0In,
            amount1In,
            width
        );

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager
            .MintParams({
                token0: info.token0,
                token1: info.token1,
                fee: info.feeProtocol,
                tickLower: _fitTickSpacing(tickLower, info.tickSpacing, false),
                tickUpper: _fitTickSpacing(tickUpper, info.tickSpacing, true),
                amount0Desired: amount0In,
                amount1Desired: amount1In,
                amount0Min: minAmount0,
                amount1Min: minAmount1,
                recipient: msg.sender,
                deadline: deadline
            });

        (tokenId, , amount0, amount1) = INonfungiblePositionManager(positionManager).mint(
            params
        );

        emit AddedLiquidity(tokenId, amount0, amount1);
    }

    function calculateTicks(
        uint256 sqrtPriceX96,
        uint256 dY,
        uint256 dX,
        uint256 width
    )
        public
        pure
        returns (
            int24 tickLower,
            int24 tickUpper,
            uint256 sqrtPriceX96Lower,
            uint256 sqrtPriceX96Upper
        )
    {
        /**
         * P_b > P > P_a
         * dX > 0
         * dY > 0
         * W = (P_b - P_a) * 10^4 / (P_b + P_a)
         * P_b, P_a - ?
         *
         * dX, dY > 0 => dL_x, dL_y > 0
         *
         * dL_x = L / (1/sqrt(P) - 1/sqrt(P_b))
         * dL_y = L / (sqrt(P) - sqrt(P_a))
         *
         * T = sqrt((10^4 + W) / (10^4 - W)) > 1
         *
         * (dX * P * T) * P_a^2 + T(dY - dX * P^2) * P_a - dY * P = 0 | : Q96
         * we can divide both sides by Q96 to prevent overflow (decreases accuracy of roots)
         *
         * coefA > 0
         * coefB ?? 0
         * coefC < 0
         *
         * solve as quadratic equation for P_a
         * find P_b = T^2 * P_a
         *
         * sqrtPriceX96 = sqrt(P) * 2^96
         * P = 1.0001^tick => tick = log_1.0001(P)
         * using Uniswap TickMath::getTickAtSqrtRatio
         */

        require(width < DENOMINATOR && width != 0, 'Invalid width');
        require(
            sqrtPriceX96 >= TickMath.MIN_SQRT_RATIO &&
                sqrtPriceX96 < TickMath.MAX_SQRT_RATIO,
            'Invalid spot price'
        );

        require(dY != 0, 'Invalid amount 0');
        require(dX != 0, 'Invalid amount 1');

        {
            uint256 sqrtTNumeratorD = Math.sqrt((DENOMINATOR + width) * DENOMINATOR);
            uint256 sqrtTDenominatorD = Math.sqrt((DENOMINATOR - width) * DENOMINATOR);

            sqrtPriceX96Lower = _buildCoefficientsAndSolve(
                dX,
                dY,
                sqrtPriceX96,
                sqrtTNumeratorD,
                sqrtTDenominatorD
            );

            sqrtPriceX96Upper = (sqrtPriceX96Lower * sqrtTNumeratorD) / sqrtTDenominatorD;
        }

        int24 tickUpperTmp = TickMath.getTickAtSqrtRatio(uint160(sqrtPriceX96Upper));
        int24 tickLowerTmp = TickMath.getTickAtSqrtRatio(uint160(sqrtPriceX96Lower));

        (tickUpper, tickLower) = tickUpperTmp > tickLowerTmp
            ? (tickUpperTmp, tickLowerTmp)
            : (tickLowerTmp, tickUpperTmp);
    }

    function _fitTickSpacing(
        int24 tick,
        int24 tickSpacing,
        bool floor
    ) private pure returns (int24) {
        return
            floor
                ? (tick - (tick % tickSpacing))
                : (tick - (tick % tickSpacing) + tickSpacing);
    }

    function _getPoolInfo(address pool) private view returns (PoolInfo memory info) {
        address token0 = IUniswapV3Pool(pool).token0();
        address token1 = IUniswapV3Pool(pool).token1();
        (uint160 sqrtPriceX96, , , , , uint8 feeProtocol, ) = IUniswapV3Pool(pool)
            .slot0();

        int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();

        info = PoolInfo({
            sqrtPriceX96: sqrtPriceX96,
            feeProtocol: feeProtocol,
            token0: token0,
            token1: token1,
            tickSpacing: tickSpacing
        });
    }

    function _buildCoefficientsAndSolve(
        uint256 dX,
        uint256 dY,
        uint256 sqrtPriceX96,
        uint256 sqrtTNumeratorD,
        uint256 sqrtTDenominatorD
    ) private pure returns (uint256) {
        // dX * T * P
        uint256 coefA = ((dX * sqrtTNumeratorD * sqrtPriceX96) /
            (sqrtTDenominatorD * Q96));

        (bool signB, uint256 coefBNumerator) = _absDiff(
            (dY * sqrtTNumeratorD) / Q96,
            ((dX * sqrtTNumeratorD * sqrtPriceX96) / Q96) * sqrtPriceX96
        );

        // T(dY - dX * P^2)
        uint256 coefB = (coefBNumerator) / (sqrtTDenominatorD);

        // -dY * P
        uint256 coefC = ((dY * sqrtPriceX96) / Q96);

        uint256 root = _solveQuadratic(coefA, coefB, coefC, signB);

        return root;
    }

    function _absDiff(
        uint256 a,
        uint256 b
    ) private pure returns (bool sign, uint256 res) {
        return (a > b) ? (true, a - b) : (false, b - a);
    }

    function _getActualMinAmounts(
        uint256 amount0In,
        uint256 amount1In,
        uint256 accuracyDeltaNumerator
    ) private pure returns (uint256, uint256) {
        return (
            (amount0In * (DENOMINATOR - accuracyDeltaNumerator)) / DENOMINATOR,
            (amount1In * (DENOMINATOR - accuracyDeltaNumerator)) / DENOMINATOR
        );
    }

    function _solveQuadratic(
        uint256 a,
        uint256 b,
        uint256 c,
        bool signB
    ) private pure returns (uint256 rootPositive) {
        // A > 0, C < 0

        // +aX^2 + (signB)* bX - c = 0
        // D = + b^2 + 4*a*c
        // x1 = (-(signB)b + sqrt(D)) / 2a
        // x2 = (-(signB)b - sqrt(D)) / 2a
        // D >= 0

        // escaping overflow (increasing inaccuracy)
        uint256 sqrtD = Math.sqrt(b * (b / Q96) + (4 * a * c) / Q96) * Q48;

        // 1 root is positive, 1 is negative
        if (signB) {
            rootPositive = (sqrtD - b) / (2 * a);
            // rootNegative = (-sqrtD - b) / (2 * a)
        } else {
            rootPositive = (sqrtD + b) / (2 * a);
            // rootNegative = (-sqrtD + b) / (2 * a)
        }
    }
}
