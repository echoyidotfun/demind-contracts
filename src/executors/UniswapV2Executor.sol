// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../lib/SafeERC20.sol";
import "../interfaces/executors/uniswapv2/IUniswapFactory.sol";
import "../interfaces/executors/uniswapv2/IUniswapPair.sol";
import "./ExecutorBase.sol";

contract UniswapV2Executor is ExecutorBase {
    using SafeERC20 for IERC20;

    uint256 internal constant FEE_DENOMINATOR = 1e3;
    uint256 public immutable feeCompliment;
    address public immutable factory;

    constructor(string memory _name, address _factory, uint256 _fee, uint256 _swapGasEstimate)
        ExecutorBase(_name, _swapGasEstimate)
    {
        factory = _factory;
        feeCompliment = FEE_DENOMINATOR - _fee;
    }

    function _query(uint256 _amountIn, address _tokenIn, address _tokenOut)
        internal
        view
        override
        returns (uint256 amountOut)
    {
        if (_tokenIn == _tokenOut || _amountIn == 0) {
            return 0;
        }
        address pair = IUniswapFactory(factory).getPair(_tokenIn, _tokenOut);
        if (pair == address(0)) {
            return 0;
        }
        (uint256 reserve0, uint256 reserve1,) = IUniswapPair(pair).getReserves();
        (uint256 reserveIn, uint256 reserveOut) = _tokenIn < _tokenOut ? (reserve0, reserve1) : (reserve1, reserve0);
        if (reserveIn > 0 && reserveOut > 0) {
            amountOut = _getAmountOut(_amountIn, reserveIn, reserveOut);
        }
    }

    function _getAmountOut(uint256 _amountIn, uint256 _reserveIn, uint256 _reserveOut)
        internal
        view
        returns (uint256 amountOut)
    {
        uint256 amountInWithFee = _amountIn * feeCompliment; // 0.1 * fee
        uint256 numerator = amountInWithFee * _reserveOut; // 0.1 * fee * 200
        uint256 denominator = (_reserveIn * FEE_DENOMINATOR) + amountInWithFee; // 1 * fee + 0.1 * fee
        amountOut = numerator / denominator;
    }

    function _swap(uint256 _amountIn, uint256 _amountOut, address _tokenIn, address _tokenOut, address _to)
        internal
        override
    {
        address pair = IUniswapFactory(factory).getPair(_tokenIn, _tokenOut);
        (uint256 amount0Out, uint256 amount1Out) =
            (_tokenIn < _tokenOut) ? (uint256(0), _amountOut) : (_amountOut, uint256(0));
        IERC20(_tokenIn).safeTransfer(pair, _amountIn);
        IUniswapPair(pair).swap(amount0Out, amount1Out, _to, new bytes(0));
    }
}
