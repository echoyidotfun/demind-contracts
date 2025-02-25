// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "../interfaces/executors/uniswapv3/IUniswapV3Factory.sol";
import "./UniswapV3LikeExecutor.sol";

abstract contract UniswapV3ExecutorBase is UniswapV3LikeExecutor {
    using SafeERC20 for IERC20;

    error AlreadyEnabled();
    error FeeAmountNotSupported();

    address immutable i_factory;
    mapping(uint24 => bool) public isFeeAmountEnabled;
    uint24[] public feeAmounts;

    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        uint256 _quoteGasLimit,
        address _quoter,
        address _factory,
        uint24[] memory _defaultFees
    ) UniswapV3LikeExecutor(_name, _swapGasEstimate, _quoter, _quoteGasLimit) {
        i_factory = _factory;
        for (uint256 i = 0; i < _defaultFees.length; i++) {
            addFeeAmount(_defaultFees[i]);
        }
    }

    function enableFeeAmounts(uint24[] calldata _amounts) external onlyOwner {
        for (uint256 i = 0; i < _amounts.length; i++) {
            enableFeeAmount(_amounts[i]);
        }
    }

    function enableFeeAmount(uint24 _feeAmount) internal {
        require(!isFeeAmountEnabled[_feeAmount], AlreadyEnabled());
        if (IUniswapV3Factory(i_factory).feeAmountTickSpacing(_feeAmount) == 0) {
            revert FeeAmountNotSupported();
        }
        addFeeAmount(_feeAmount);
    }

    function addFeeAmount(uint24 _feeAmount) internal {
        isFeeAmountEnabled[_feeAmount] = true;
        feeAmounts.push(_feeAmount);
    }

    function getBestPool(address _token0, address _token1) internal view override returns (address bestPool) {
        uint128 deepestLiquidity;
        for (uint256 i = 0; i < feeAmounts.length; i++) {
            address pool = IUniswapV3Factory(i_factory).getPool(_token0, _token1, feeAmounts[i]);
            if (pool == address(0)) continue;
            uint128 liquidity = IUniswapV3Pool(pool).liquidity();
            if (liquidity > deepestLiquidity) {
                deepestLiquidity = liquidity;
                bestPool = pool;
            }
        }
    }
}
