// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/SafeERC20.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/executors/uniswapv3/IUniswapV3Quoter.sol";
import "../interfaces/executors/uniswapv3/IUniswapV3Pool.sol";
import "./ExecutorBase.sol";

abstract contract UniswapV3LikeExecutor is ExecutorBase {
    using SafeERC20 for IERC20;

    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint256 public quoterGasLimit;
    address public quoter;

    constructor(string memory _name, uint256 _swapGasEstimate, address _quoter, uint256 _quoterGasLimit)
        ExecutorBase(_name, _swapGasEstimate)
    {
        setQuoter(_quoter);
        setQuoteGasEstimate(_quoterGasLimit);
    }

    function setQuoter(address _quoter) public onlyOwner {
        quoter = _quoter;
    }

    function setQuoteGasEstimate(uint256 _quoterGasLimit) public onlyOwner {
        quoterGasLimit = _quoterGasLimit;
    }

    function getQuoteFromPool(address _pool, int256 _amountIn, address _tokenIn, address _tokenOut)
        external
        view
        returns (uint256)
    {
        QParams memory params;
        params.amountIn = _amountIn;
        params.tokenIn = _tokenIn;
        params.tokenOut = _tokenOut;
        return getQuoteFromPool(_pool, params);
    }

    function _query(uint256 _amountIn, address _tokenIn, address _tokenOut)
        internal
        view
        override
        returns (uint256 quote)
    {
        QParams memory params = getQParams(_amountIn, _tokenIn, _tokenOut);
        quote = getQuoteFromBestPool(params);
    }

    function _swap(uint256 _amountIn, uint256 _amountOut, address _tokenIn, address _tokenOut, address _to)
        internal
        override
    {
        QParams memory params = getQParams(_amountIn, _tokenIn, _tokenOut);
        uint256 amountOut = _underlyingSwap(params, new bytes(0));
        require(amountOut >= _amountOut, InsufficientAmountOut());
        _returnTo(_tokenOut, amountOut, _to);
    }

    function getQuoteFromBestPool(QParams memory params) internal view returns (uint256 quote) {
        address bestPool = getBestPool(params.tokenIn, params.tokenOut);
        if (bestPool != address(0)) {
            quote = getQuoteFromPool(bestPool, params);
        }
    }

    function getBestPool(address _token0, address _token1) internal view virtual returns (address bestPool);

    function getQuoteFromPool(address _pool, QParams memory params) internal view returns (uint256) {
        (bool zeroForOne, uint160 priceLimit) = getZeroOneAndSqrtPriceLimitX96(params.tokenIn, params.tokenOut);
        (int256 amount0, int256 amount1) = getQuoteSafe(_pool, zeroForOne, params.amountIn, priceLimit);
        return zeroForOne ? uint256(-amount1) : uint256(-amount0);
    }

    function getQuoteSafe(address _pool, bool zeroForOne, int256 _amountIn, uint160 _priceLimit)
        internal
        view
        returns (int256 amount0, int256 amount1)
    {
        bytes memory calldata_ =
            abi.encodeWithSignature("quote(address, bool, int256, uint160)", _pool, zeroForOne, _amountIn, _priceLimit);

        (bool success, bytes memory returnData) = quoter.staticcall{gas: quoterGasLimit}(calldata_);
        if (success) {
            (amount0, amount1) = abi.decode(returnData, (int256, int256));
        }
    }

    function _underlyingSwap(QParams memory params, bytes memory callbackData) internal virtual returns (uint256) {
        address pool = getBestPool(params.tokenIn, params.tokenOut);
        (bool zeroForOne, uint160 priceLimit) = getZeroOneAndSqrtPriceLimitX96(params.tokenIn, params.tokenOut);
        (int256 amount0, int256 amount1) =
            IUniswapV3Pool(pool).swap(address(this), zeroForOne, params.amountIn, priceLimit, callbackData);
        return zeroForOne ? uint256(-amount1) : uint256(-amount0);
    }

    // interIUniswapV3Pooltils

    function getQParams(uint256 _amountIn, address _tokenIn, address _tokenOut)
        internal
        pure
        returns (QParams memory params)
    {
        params = QParams({amountIn: int256(_amountIn), tokenIn: _tokenIn, tokenOut: _tokenOut, fee: 0});
    }

    function getZeroOneAndSqrtPriceLimitX96(address _tokenIn, address _tokenOut)
        internal
        pure
        returns (bool zeroForOne, uint160 sqrtPriceLimitX96)
    {
        zeroForOne = _tokenIn < _tokenOut;
        sqrtPriceLimitX96 = zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1;
    }
}
