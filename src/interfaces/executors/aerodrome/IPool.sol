// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPool {
    /// @notice Address of token in the pool with the lower address value
    function token0() external view returns (address);

    /// @notice Address of token in the poool with the higher address value
    function token1() external view returns (address);

    /// @notice Amount of token0 in pool
    function reserve0() external view returns (uint256);

    /// @notice Amount of token1 in pool
    function reserve1() external view returns (uint256);

    /// @notice True if pool is stable, false if volatile
    function stable() external view returns (bool);

    /// @notice Provides twap price with user configured granularity, up to the full window size
    /// @param tokenIn .
    /// @param amountIn .
    /// @param granularity .
    /// @return amountOut .
    function quote(address tokenIn, uint256 amountIn, uint256 granularity) external view returns (uint256 amountOut);

    /// @notice This low-level function should be called from a contract which performs important safety checks
    /// @param amount0Out   Amount of token0 to send to `to`
    /// @param amount1Out   Amount of token1 to send to `to`
    /// @param to           Address to recieve the swapped output
    /// @param data         Additional calldata for flashloans
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    /// @notice Get the amount of tokenOut given the amount of tokenIn
    /// @param amountIn Amount of token in
    /// @param tokenIn  Address of token
    /// @return Amount out
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
}
