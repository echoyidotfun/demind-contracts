// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUniswapV3Factory {
    function feeAmountTickSpacing(uint24) external view returns (int24);

    function getPool(address, address, uint24) external view returns (address);
}
