// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/executors/aerodrome/IPoolFactory.sol";
import "../interfaces/executors/aerodrome/IPool.sol";
import "./ExecutorBase.sol";

contract AerodromeExecutor is ExecutorBase {
    using SafeERC20 for IERC20;

    address immutable i_factory;

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
        (amountOut,) = getQuoteAndPool(_amountIn, _tokenIn, _tokenOut);
    }

    function _swap(uint256 _amountIn, uint256 _amountOut, address _tokenIn, address _tokenOut, address _to)
        internal
        override
    {
        (uint256 amountOut, address pool) = getQuoteAndPool(_amountIn, _tokenIn, _tokenOut);
        if (amountOut < _amountOut) revert InsufficientAmountOut();
        (uint256 amount0Out, uint256 amount1Out) =
            (_tokenIn < _tokenOut) ? (uint256(0), amountOut) : (amountOut, uint256(0));
        IERC20(_tokenIn).safeTransfer(pool, _amountIn);
        IPool(pool).swap(amount0Out, amount1Out, _to, new bytes(0));
    }

    function getQuoteAndPool(uint256 _amountIn, address _tokenIn, address _tokenOut)
        internal
        view
        returns (uint256 amountOut, address pool)
    {
        address poolStable = poolFor(_tokenIn, _tokenOut, true);
        address poolVolatile = poolFor(_tokenIn, _tokenOut, false);
        uint256 amountStable;
        uint256 amountVolatile;
        if (IPoolFactory(i_factory).isPool(poolStable)) {
            amountStable = _getAmountOutSafe(poolStable, _amountIn, _tokenIn);
        }
        if (IPoolFactory(i_factory).isPool(poolVolatile)) {
            amountVolatile = _getAmountOutSafe(poolVolatile, _amountIn, _tokenIn);
        }
        (amountOut, pool) = amountStable > amountVolatile ? (amountStable, poolStable) : (amountVolatile, poolVolatile);
    }

    function poolFor(address _tokenA, address _tokenB, bool stable) internal view returns (address pool) {
        (address token0, address token1) = sortTokens(_tokenA, _tokenB);
        bytes32 salt = keccak256(abi.encodePacked(token0, token1, stable));
        pool = Clones.predictDeterministicAddress(IPoolFactory(i_factory).implementation(), salt, i_factory);
    }

    function _getAmountOutSafe(address pool, uint256 amountIn, address tokenIn) internal view returns (uint256) {
        try IPool(pool).getAmountOut(amountIn, tokenIn) returns (uint256 amountOut) {
            return amountOut;
        } catch {
            return 0;
        }
    }

    function sortTokens(address _token0, address _token1) internal pure returns (address token0, address token1) {
        (token0, token1) = _token0 < _token1 ? (_token0, _token1) : (_token1, _token0);
    }
}
