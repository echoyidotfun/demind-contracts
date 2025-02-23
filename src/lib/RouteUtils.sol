// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TypeConversion} from "./TypeConversion.sol";
import {Route, FormattedRoute} from "../interfaces/IAggregationRouter.sol";

library RouteUtils {
    using TypeConversion for address;
    using TypeConversion for uint256;
    using TypeConversion for bytes;

    function newRoute(uint256 _amountIn, address _tokenIn) internal pure returns (Route memory route) {
        route.amounts = _amountIn.toBytes();
        route.path = _tokenIn.toBytes();
    }

    /**
     * Makes a deep copy of Route struct
     */
    function clone(Route memory _queries) internal pure returns (Route memory) {
        return Route(_queries.amounts, _queries.executors, _queries.path, _queries.gasEstimate);
    }

    /**
     * Appends new elements to the end of Route struct
     */
    function addToTail(
        Route memory _queries,
        uint256 _amount,
        address _executor,
        address _tokenOut,
        uint256 _gasEstimate
    ) internal pure {
        _queries.path = bytes.concat(_queries.path, _tokenOut.toBytes());
        _queries.executors = bytes.concat(_queries.executors, _executor.toBytes());
        _queries.amounts = bytes.concat(_queries.amounts, _amount.toBytes());
        _queries.gasEstimate += _gasEstimate;
    }

    /**
     * Formats elements in the Route object from byte-arrays to integers and addresses
     */
    function format(Route memory _queries) internal pure returns (FormattedRoute memory) {
        return FormattedRoute(
            _queries.amounts.toUints(),
            _queries.executors.toAddresses(),
            _queries.path.toAddresses(),
            _queries.gasEstimate
        );
    }

    function getTokenOut(Route memory _route) internal pure returns (address tokenOut) {
        tokenOut = _route.path.toAddress(_route.path.length); // Last 32 bytes
    }

    function getAmountOut(Route memory _route) internal pure returns (uint256 amountOut) {
        amountOut = _route.amounts.toUint(_route.path.length); // Last 32 bytes
    }
}
