// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPairFactory {
    /// @notice calculates if the address is a legacy pair
    /// @param pair the address to check
    /// @return _boolean the bool return
    function isPair(address pair) external view returns (bool _boolean);

    /// @param tokenA address of tokenA
    /// @param tokenB address of tokenB
    /// @param stable whether it uses the stable curve
    /// @return _pair the address of the pair
    function getPair(address tokenA, address tokenB, bool stable) external view returns (address _pair);
}
