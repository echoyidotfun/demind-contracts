// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPair {
    /// @notice calculates the amount of tokens to receive post swap
    /// @param amountIn the token amount
    /// @param tokenIn the address of the token
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256 amountOut);

    /// @notice direct swap through the pool
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}
