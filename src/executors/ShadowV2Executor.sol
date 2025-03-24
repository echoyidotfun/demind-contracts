// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./RamsesV2Executor.sol";

contract ShadowV2Executor is RamsesV2Executor {
    constructor(string memory _name, address _factory, uint256 _swapGasEstimate)
        RamsesV2Executor(_name, _factory, _swapGasEstimate)
    {}
}
