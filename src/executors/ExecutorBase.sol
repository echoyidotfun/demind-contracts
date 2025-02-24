// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IERC20.sol";

abstract contract ExecutorBase is Ownable {
    using SafeERC20 for IERC20;

    error NotingToRecover();
    error InsufficientAmountOut();

    event UpdatedGasEstimate(address indexed _executor, uint256 _gasEstimate);
    event ExecutedSwap(address indexed _tokenIn, address indexed _tokenOut, uint256 _amountIn, uint256 _amountOut);
    event Recovered(address indexed _asset, uint256 _amount);

    uint256 internal constant UINT_MAX = type(uint256).max;
    uint256 public swapGasEstimate;
    string public name;

    constructor(string memory _name, uint256 _swapGasEstimate) Ownable(msg.sender) {
        setName(_name);
        setSwapGasEstimate(_swapGasEstimate);
    }

    function setName(string memory _name) public onlyOwner {
        name = _name;
    }

    function setSwapGasEstimate(uint256 _swapGasEstimate) public onlyOwner {
        swapGasEstimate = _swapGasEstimate;
    }

    function revokeAllowance(address _token, address _spender) external onlyOwner {
        IERC20(_token).safeApprove(_spender, 0);
    }

    function recoverERC20(address _token, uint256 _amount) external onlyOwner {
        require(_amount > 0, NotingToRecover());
        IERC20(_token).safeTransfer(msg.sender, _amount);
        emit Recovered(_token, _amount);
    }

    function query(uint256 _amountIn, address _tokenIn, address _tokenOut) external view returns (uint256 amountOut) {
        return _query(_amountIn, _tokenIn, _tokenOut);
    }

    function swap(uint256 _amountIn, uint256 _amountOut, address _tokenIn, address _tokenOut, address _to)
        external
        virtual
    {
        uint256 balanceBefore = IERC20(_tokenOut).balanceOf(_to);
        _swap(_amountIn, _amountOut, _tokenIn, _tokenOut, _to);
        uint256 balanceDiff = IERC20(_tokenOut).balanceOf(_to) - balanceBefore;
        require(balanceDiff >= _amountOut, InsufficientAmountOut());
        emit ExecutedSwap(_tokenIn, _tokenOut, _amountIn, _amountOut);
    }

    function _returnTo(address _token, uint256 _amount, address _to) internal {
        if (address(this) != _to) {
            IERC20(_token).safeTransfer(_to, _amount);
        }
    }

    function _swap(uint256 _amountIn, uint256 _amountOut, address _tokenIn, address _tokenOut, address _to)
        internal
        virtual;

    function _query(uint256 _amountIn, address _tokenIn, address _tokenOut) internal view virtual returns (uint256);

    // fallback
    receive() external payable {}
}
