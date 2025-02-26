// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct Query {
    address executor;
    address tokenIn;
    address tokenOut;
    uint256 amountOut;
}

struct Route {
    bytes amounts;
    bytes executors;
    bytes path;
    uint256 gasEstimate;
}

struct PathStep {
    uint256 amountIn;
    address tokenIn;
    Route queries;
}

struct FormattedRoute {
    uint256[] amounts;
    address[] executors;
    address[] path;
    uint256 gasEstimate;
}

struct TradeSummary {
    uint256 amountIn;
    uint256 amountOut;
    address[] path;
    address[] executors;
}

interface IAggregationRouter {
    error InvalidMaxSteps(uint256 _maxSteps);
    error InsufficientAmountOut();
    error InsufficientFees();
    error FromWrappedNative();
    error ToWrappedNative();

    event UpdatedTruestedTokens(address[] _newTruestedTokens);
    event UpdatedExecutors(address[] _newExecutors);
    event UpdateMinFee(uint256 _oldMinFee, uint256 _newMinFee);
    event UpdatedFeeClaimer(address _oldFeeClaimer, address _newFeeClaimer);
    event Swapped(address indexed _tokenIn, address indexed _tokenOut, uint256 _amountIn, uint256 _amountOut);

    // admin
    function setTrustedTokens(address[] calldata _trustedTokens) external;
    function setExecutors(address[] calldata _executors) external;
    function setMinFee(uint256 _minFee) external;
    function setFeeClaimer(address _feeClaimer) external;

    // misc
    function trustedTokensCount() external view returns (uint256);
    function executorsCount() external view returns (uint256);

    // QUERIES

    /**
     * @notice query single executor
     * @param _amountIn amount in
     * @param _tokenIn token in
     * @param _tokenOut token out
     */
    function queryExecutor(uint256 _amountIn, address _tokenIn, address _tokenOut, uint8 index)
        external
        view
        returns (uint256);

    /**
     * @notice query specified executors
     */
    function queryNoSplit(uint256 _amountIn, address _tokenIn, address _tokenOut, uint8[] calldata _options)
        external
        view
        returns (Query memory query);

    /**
     * @notice query all executors
     */
    function queryNoSplit(uint256 _amountIn, address _tokenIn, address _tokenOut)
        external
        view
        returns (Query memory);

    /**
     * @notice Return path with best quote between two tokens
     * @dev takes gas cost into account.
     */
    function findBestPathWithGas(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint256 _maxSteps,
        uint256 _gasPrice
    ) external view returns (FormattedRoute memory);

    /**
     * @notice Return path with best quote between two tokens
     */
    function findBestPath(uint256 _amountIn, address _tokenIn, address _tokenOut, uint256 _maxSteps)
        external
        view
        returns (FormattedRoute memory route);

    // swap
    function swapNoSplit(TradeSummary calldata _trade, address _to, uint256 _fee) external;

    function swapNoSplitFromNative(TradeSummary calldata _trade, address _to, uint256 _fee) external payable;

    function swapNoSplitToNative(TradeSummary calldata _trade, address _to, uint256 _fee) external;

    // function swapNoSplitWithPermit(
    //     TradeSummary calldata _trade,
    //     address _to,
    //     uint256 _fee,
    //     uint256 _deadline,
    //     uint8 _v,
    //     bytes32 _r,
    //     bytes32 _s
    // ) external;
}
