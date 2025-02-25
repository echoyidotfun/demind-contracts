// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct QParams {
    address tokenIn;
    address tokenOut;
    int256 amountIn;
    uint24 fee;
}

interface IUniswapV3Quoter {
    function quoteExactInputSingle(QParams memory params) external view returns (uint256);

    function quote(address, bool, int256, uint160) external view returns (int256, int256);
}
