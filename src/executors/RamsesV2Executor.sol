// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/SafeERC20.sol";
import "../interfaces/executors/ramsesv2/IPairFactory.sol";
import "../interfaces/executors/ramsesv2/IPair.sol";
import "./ExecutorBase.sol";

contract RamsesV2Executor is ExecutorBase {
    using SafeERC20 for IERC20;

    address public immutable i_factory;

    constructor(string memory _name, address _factory, uint256 _swapGasEstimate)
        ExecutorBase(_name, _swapGasEstimate)
    {
        i_factory = _factory;
    }

    function _query(uint256 _amountIn, address _tokenIn, address _tokenOut)
        internal
        view
        override
        returns (uint256 amountOut)
    {
        (amountOut,) = _getQuoteAndPair(_tokenIn, _tokenOut, _amountIn);
    }

    function _swap(uint256 _amountIn, uint256 _amountOut, address _tokenIn, address _tokenOut, address _to)
        internal
        override
    {
        (uint256 amountOut, address pair) = _getQuoteAndPair(_tokenIn, _tokenOut, _amountIn);
        if (amountOut < _amountOut) revert InsufficientAmountOut();
        (uint256 amount0Out, uint256 amount1Out) =
            (_tokenIn < _tokenOut) ? (uint256(0), amountOut) : (amountOut, uint256(0));
        IERC20(_tokenIn).safeTransfer(pair, _amountIn);
        IPair(pair).swap(amount0Out, amount1Out, _to, new bytes(0));
    }

    function _getQuoteAndPair(address _tokenIn, address _tokenOut, uint256 _amountIn)
        internal
        view
        returns (uint256, address)
    {
        address stablePair = IPairFactory(i_factory).getPair(_tokenIn, _tokenOut, true);
        uint256 amountOutStable;
        uint256 amountOutVolatile;
        if (stablePair != address(0) && IPairFactory(i_factory).isPair(stablePair)) {
            amountOutStable = _getAmountOut(stablePair, _amountIn, _tokenIn);
        }
        address volatilePair = IPairFactory(i_factory).getPair(_tokenIn, _tokenOut, false);
        if (volatilePair != address(0) && IPairFactory(i_factory).isPair(volatilePair)) {
            amountOutVolatile = _getAmountOut(volatilePair, _amountIn, _tokenIn);
        }
        return amountOutStable > amountOutVolatile ? (amountOutStable, stablePair) : (amountOutVolatile, volatilePair);
    }

    function _getAmountOut(address _pair, uint256 _amountIn, address _tokenIn) internal view returns (uint256) {
        try IPair(_pair).getAmountOut(_amountIn, _tokenIn) returns (uint256 amountOut) {
            return amountOut;
        } catch {
            return 0;
        }
    }
}
