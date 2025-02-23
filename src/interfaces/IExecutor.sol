// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IExecutor {
    function name() external view returns (string memory);

    function swapGasEstimate() external view returns (uint256);

    function swap(uint256 _amountIn, uint256 _amountOut, address _tokenIn, address _tokenOut, address _to)
        external
        payable;

    function query(uint256 _amountIn, address _tokenIn, address _tokenOut) external view returns (uint256);
}
