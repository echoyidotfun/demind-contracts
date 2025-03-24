// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {RouteUtils} from "../lib/RouteUtils.sol";
import {IExecutor} from "../interfaces/executors/IExecutor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IAggregationRouter.sol";
import {IWrappedNative} from "../interfaces/IWrappedNative.sol";
import {MockWETH} from "test/utils/MockWETH.sol";

/**
 * @title DemindRouter: core aggregation router contract
 * @author echoyi
 */
contract DemindRouter is IAggregationRouter, Ownable {
    using SafeERC20 for IERC20;
    using RouteUtils for Route;

    address public immutable WNATIVE;
    address public constant NATIVE = address(0);
    string public constant NAME = "DemindRouter";
    uint256 public constant FEE_DENOMINATOR = 1e4;
    uint256 internal constant UINT_MAX = type(uint256).max;

    uint256 public MIN_FEE = 0;
    address public FEE_CLIAIMER;

    address[] public trustedTokens;
    address[] public executors;

    constructor(
        address[] memory _executors,
        address[] memory _trustedTokens,
        address _feeClaimer,
        address _wrappedNative
    ) Ownable(msg.sender) {
        setAllowanceForWrapping(_wrappedNative);
        setTrustedTokens(_trustedTokens);
        setExecutors(_executors);
        setFeeClaimer(_feeClaimer);
        WNATIVE = _wrappedNative;
    }

    function setAllowanceForWrapping(address _wrappedNative) public onlyOwner {
        IERC20(_wrappedNative).safeIncreaseAllowance(address(this), UINT_MAX);
    }

    function setTrustedTokens(address[] memory _trustedTokens) public override onlyOwner {
        _trustedTokens = _trustedTokens;
        emit UpdatedTrustedTokens(_trustedTokens);
    }

    function addTrustedToken(address _trustedToken) public onlyOwner {
        require(_trustedToken != address(0), ZeroAddress());
        for (uint256 i = 0; i < trustedTokens.length; i++) {
            require(trustedTokens[i] != _trustedToken, AlreadyAdded(_trustedToken));
        }
        trustedTokens.push(_trustedToken);
    }

    function deleteTrustedToken(address _trustedToken) public onlyOwner {
        bool found = false;
        for (uint256 i = 0; i < trustedTokens.length; i++) {
            if (trustedTokens[i] == _trustedToken) {
                // 将最后一个元素移到当前位置
                trustedTokens[i] = trustedTokens[trustedTokens.length - 1];
                // 删除最后一个元素
                trustedTokens.pop();
                found = true;
                emit TrustedTokenRemoved(_trustedToken);
                break;
            }
        }
        require(found, InvalidTrustedToken(_trustedToken));
    }

    function setExecutors(address[] memory _executors) public override onlyOwner {
        executors = _executors;
        emit UpdatedExecutors(executors);
    }

    function addExecutor(address _executor) public onlyOwner {
        require(_executor != address(0), ZeroAddress());
        for (uint256 i = 0; i < executors.length; i++) {
            require(executors[i] != _executor, AlreadyAdded(_executor));
        }
        executors.push(_executor);
        emit UpdatedExecutors(executors);
    }

    function deleteExecutor(address _executor) public onlyOwner {
        bool found = false;
        for (uint256 i = 0; i < executors.length; i++) {
            if (executors[i] == _executor) {
                // 将最后一个元素移到当前位置
                executors[i] = executors[executors.length - 1];
                executors.pop();
                found = true;
                emit UpdatedExecutors(executors);
                break;
            }
        }
        require(found, InvalidExecutor(_executor));
    }

    function setFeeClaimer(address _feeClaimer) public override onlyOwner {
        emit UpdatedFeeClaimer(FEE_CLIAIMER, _feeClaimer);
        FEE_CLIAIMER = _feeClaimer;
    }

    function setMinFee(uint256 _minFee) public override onlyOwner {
        emit UpdateMinFee(MIN_FEE, _minFee);
        MIN_FEE = _minFee;
    }

    function trustedTokensCount() external view override returns (uint256) {
        return trustedTokens.length;
    }

    function executorsCount() external view override returns (uint256) {
        return executors.length;
    }

    // fallback
    receive() external payable {}

    function _applyFee(uint256 _amountIn, uint256 _fee) internal view returns (uint256) {
        require(_fee >= MIN_FEE, InsufficientFees());
        return (_amountIn * (FEE_DENOMINATOR - _fee)) / FEE_DENOMINATOR;
    }

    function _wrap(uint256 _amount) internal {
        IWrappedNative(WNATIVE).deposit{value: _amount}();
    }

    function _unwrap(uint256 _amount) internal {
        IWrappedNative(WNATIVE).withdraw(_amount);
    }

    function _transferFrom(address _token, address _from, address _to, uint256 _amount) internal {
        if (_from != address(this)) {
            IERC20(_token).safeTransferFrom(_from, _to, _amount);
        } else {
            IERC20(_token).safeTransfer(_to, _amount);
        }
    }

    /// @inheritdoc IAggregationRouter
    function queryExecutor(uint256 _amountIn, address _tokenIn, address _tokenOut, uint8 _index)
        external
        view
        override
        returns (uint256 amountOut)
    {
        amountOut = IExecutor(executors[_index]).query(_amountIn, _tokenIn, _tokenOut);
    }

    /// @inheritdoc IAggregationRouter
    function queryNoSplit(uint256 _amountIn, address _tokenIn, address _tokenOut, uint8[] calldata _options)
        public
        view
        override
        returns (Query memory bestQuery)
    {
        for (uint8 i; i < _options.length; i++) {
            address _executor = executors[_options[i]];
            uint256 amountOut = IExecutor(_executor).query(_amountIn, _tokenIn, _tokenOut);
            if (i == 0 || amountOut > bestQuery.amountOut) {
                bestQuery = Query(_executor, _tokenIn, _tokenOut, amountOut);
            }
        }
    }

    /// @inheritdoc IAggregationRouter
    function queryNoSplit(uint256 _amountIn, address _tokenIn, address _tokenOut)
        public
        view
        override
        returns (Query memory bestQuery)
    {
        for (uint8 i; i < executors.length; i++) {
            address _executor = executors[i];
            uint256 amountOut = IExecutor(_executor).query(_amountIn, _tokenIn, _tokenOut);
            if (i == 0 || amountOut > bestQuery.amountOut) {
                bestQuery = Query(_executor, _tokenIn, _tokenOut, amountOut);
            }
        }
    }

    /// @inheritdoc IAggregationRouter
    function findBestPath(uint256 _amountIn, address _tokenIn, address _tokenOut, uint256 _maxSteps)
        public
        view
        override
        returns (FormattedRoute memory)
    {
        return findBestPathWithGas(_amountIn, _tokenIn, _tokenOut, _maxSteps, 0);
    }

    /// @inheritdoc IAggregationRouter
    function findBestPathWithGas(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint256 _maxSteps,
        uint256 _gasPrice
    ) public view override returns (FormattedRoute memory) {
        require(_maxSteps > 0 && _maxSteps < 5, InvalidMaxSteps(_maxSteps));
        Route memory queries = RouteUtils.newRoute(_amountIn, _tokenIn);
        uint256 gasPriceInTokenOut = _gasPrice > 0 ? _getGasPriceInTokenOut(_gasPrice, _tokenOut) : 0;
        queries = _findBestPath(_amountIn, _tokenIn, _tokenOut, _maxSteps, queries, gasPriceInTokenOut);
        if (queries.executors.length == 0) {
            queries.amounts = "";
            queries.path = "";
        }
        return queries.format();
    }

    function _getGasPriceInTokenOut(uint256 _gasPrice, address _tokenOut) internal view returns (uint256 price) {
        FormattedRoute memory gasQuery = findBestPath(1e18, WNATIVE, _tokenOut, 2);
        if (gasQuery.path.length != 0) {
            price = (gasQuery.amounts[gasQuery.amounts.length - 1] * _gasPrice) / 1e9;
        }
    }

    /**
     * @notice Finds the best path for token swapping from `_tokenIn` to `_tokenOut`.
     * @dev This function uses a depth-first search approach with a stack to explore possible paths.
     * It considers both direct and multi-step routes, taking into account gas costs if provided.
     * @param _amountIn The initial amount of the input token.
     * @param _tokenIn The address of the input token.
     * @param _tokenOut The address of the output token.
     * @param _maxSteps The maximum number of steps allowed in the path.
     * @param _queries The initial route queries.
     * @param _tokenOutPriceNWei gas price of the output token in wei, used for gas cost calculations.
     * @return The best route found for the token swap.
     */
    function _findBestPath(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint256 _maxSteps,
        Route memory _queries,
        uint256 _tokenOutPriceNWei
    ) internal view returns (Route memory) {
        Route memory bestOption = _queries.clone();
        uint256 bestAmountOut = 0;
        bool withGas = _tokenOutPriceNWei > 0;

        PathInPlanning[] memory pathSteps = new PathInPlanning[](100);
        uint256 stackSize = 1;
        pathSteps[0] = PathInPlanning(_amountIn, _tokenIn, _queries, false);
        while (stackSize > 0) {
            PathInPlanning memory current = pathSteps[stackSize - 1];
            stackSize--;

            uint256 gasEstimate = 0;
            Query memory queryDirect = queryNoSplit(current.amountIn, current.tokenIn, _tokenOut);
            if (queryDirect.amountOut > 0) {
                if (withGas) {
                    gasEstimate = IExecutor(queryDirect.executor).swapGasEstimate();
                }
                Route memory newRoute = current.route.clone();
                newRoute.addToTail(queryDirect.amountOut, queryDirect.executor, queryDirect.tokenOut, gasEstimate);
                uint256 amountOut = queryDirect.amountOut;
                if (bestAmountOut == 0 || bestAmountOut < amountOut) {
                    if (withGas && bestAmountOut > 0 && newRoute.gasEstimate > bestOption.gasEstimate) {
                        unchecked {
                            uint256 gasCostDiff =
                                (_tokenOutPriceNWei * (newRoute.gasEstimate - bestOption.gasEstimate)) / 1e9;
                            uint256 amountOutDiff = (amountOut - bestAmountOut);
                            if (gasCostDiff <= amountOutDiff) {
                                bestOption = newRoute;
                                bestAmountOut = amountOut;
                            }
                        }
                    } else {
                        bestAmountOut = amountOut;
                        bestOption = newRoute;
                    }
                }
            }
            if (_maxSteps > 1 && current.route.executors.length / 32 <= _maxSteps - 2) {
                address[] memory pathTokens = current.route.routeToAddresses();
                for (uint256 i; i < trustedTokens.length; i++) {
                    address trustedToken = trustedTokens[i];
                    if (current.tokenIn == trustedToken || _tokenOut == trustedToken) {
                        continue;
                    }

                    bool tokenInPath = false;
                    for (uint256 j; j < pathTokens.length; j++) {
                        if (pathTokens[j] == trustedToken) {
                            tokenInPath = true;
                            break;
                        }
                    }
                    if (tokenInPath) {
                        continue;
                    }
                    Query memory bestSwap = queryNoSplit(current.amountIn, current.tokenIn, trustedToken);
                    if (bestSwap.amountOut == 0) continue;

                    Route memory newRoute = current.route.clone();
                    if (withGas) {
                        gasEstimate = IExecutor(bestSwap.executor).swapGasEstimate();
                    }
                    newRoute.addToTail(bestSwap.amountOut, bestSwap.executor, bestSwap.tokenOut, gasEstimate);
                    pathSteps[stackSize++] = PathInPlanning(bestSwap.amountOut, trustedToken, newRoute, false);
                }
            }
        }

        return bestOption;
    }

    function _swapNoSplit(TradeSummary calldata _trade, address _from, address _to, uint256 _fee)
        internal
        returns (uint256)
    {
        uint256[] memory amounts = new uint256[](_trade.path.length);
        if (_fee > 0 || MIN_FEE > 0) {
            // transfer fees to the claimer account and decrease initial amount.
            // will not apply in beta
            amounts[0] = _applyFee(_trade.amountIn);
            _transferFrom(_trade.path[0], _from, FEE_CLIAIMER, _trade.amountIn - amounts[0]);
        } else {
            amounts[0] = _trade.amountIn;
        }

        /// @dev make sure the initial amount already been sent to the first executor
        _transferFrom(_trade.path[0], _from, _trade.executors[0], amounts[0]);
        for (uint256 i; i < _trade.executors.length; i++) {
            amounts[i + 1] = IExecutor(_trade.executors[i]).query(amounts[i], _trade.path[i], _trade.path[i + 1]);
        }
        require(amounts[amounts.length - 1] >= _trade.amountOut, InsufficientAmountOut());
        for (uint256 i; i < _trade.executors.length; i++) {
            address targetAddress = i < _trade.executors.length - 1 ? _trade.executors[i + 1] : _to;
            IExecutor(_trade.executors[i]).swap(
                amounts[i], amounts[i + 1], _trade.path[i], _trade.path[i + 1], targetAddress
            );
        }

        emit Swapped(_trade.path[9], _trade.path[_trade.path.length - 1], _trade.amountIn, amounts[amounts.length - 1]);
        return amounts[amounts.length - 1];
    }

    function _applyFee(uint256 _amountIn) internal view returns (uint256) {}

    /// @inheritdoc IAggregationRouter
    function swapNoSplit(TradeSummary calldata _trade, address _to, uint256 fee) public override {
        _swapNoSplit(_trade, msg.sender, _to, fee);
    }

    function swapNoSplitFromNative(TradeSummary calldata _trade, address _to, uint256 _fee) external payable override {
        require(_trade.path[0] == WNATIVE, FromWrappedNative());
        _wrap(_trade.amountIn);
        _swapNoSplit(_trade, address(this), _to, _fee);
    }

    function swapNoSplitToNative(TradeSummary calldata _trade, address _to, uint256 _fee) public override {
        require(_trade.path[_trade.path.length - 1] == WNATIVE, ToWrappedNative());
        uint256 amountOut = _swapNoSplit(_trade, msg.sender, address(this), _fee);
        _unwrap(amountOut);
        _returnTokensTo(NATIVE, amountOut, _to);
    }

    /// @notice return tokens to user
    /// @dev pass address(0) for native token
    function _returnTokensTo(address _token, uint256 _amount, address _to) internal {
        if (address(this) != _to) {
            if (_token == NATIVE) {
                payable(_to).transfer(_amount);
            } else {
                IERC20(_token).safeTransfer(_to, _amount);
            }
        }
    }
}
