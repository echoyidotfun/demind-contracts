// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPoolFactory {
    /// @notice Is a valid pool created by this factory.
    /// @param .
    function isPool(address pool) external view returns (bool);

    /// @notice Return address of pool created by this factory
    /// @param tokenA .
    /// @param tokenB .
    /// @param stable True if stable, false if volatile
    function getPool(address tokenA, address tokenB, bool stable) external view returns (address);

    /// @notice Support for v3-style pools which wraps around getPool(tokenA,tokenB,stable)
    /// @dev fee is converted to stable boolean.
    /// @param tokenA .
    /// @param tokenB .
    /// @param fee  1 if stable, 0 if volatile, else returns address(0)
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function implementation() external view returns (address);
}
