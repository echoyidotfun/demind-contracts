// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./UniswapV3ExecutorBase.sol";
import "../interfaces/executors/pancakeswap/IPancakeV3SwapCallback.sol";

contract PancakeV3Executor is UniswapV3ExecutorBase, IPancakeV3SwapCallback {
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        uint256 _quoteGasLimit,
        address _quoter,
        address _factory,
        uint24[] memory _defaultFees
    ) UniswapV3ExecutorBase(_name, _swapGasEstimate, _quoteGasLimit, _quoter, _factory, _defaultFees) {}

    function pancakeV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        if (amount0Delta > 0) {
            IERC20(IUniswapV3Pool(msg.sender).token0()).transfer(msg.sender, uint256(amount0Delta));
        } else {
            IERC20(IUniswapV3Pool(msg.sender).token1()).transfer(msg.sender, uint256(-amount1Delta));
        }
    }
}
