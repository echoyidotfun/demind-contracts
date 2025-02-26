// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "./DeployBase.s.sol";

/// @notice scripts for executor deployments, which is previous step for router deployments
contract DeployExecutors is DeployBase {
    string public network;

    string public json = vm.readFile(jsonConfigPath);
    string public executorSrcPath = string.concat(vm.projectRoot(), "/src/executors/");

    function run() external {
        network = vm.envOr("NETWORK", string("base_sepolia"));
        console.log("Deploying all whitelisted executors on network: %s", network);
        // deploy all whitelisted executors
        string[] memory executorNames = getNetworkExecutors();
        address[] memory executorAddresses = new address[](executorNames.length);
        for (uint256 i = 0; i < executorNames.length; i++) {
            executorAddresses[i] = _deployExecutor(executorNames[i]);
        }
    }

    function getNetworkExecutors() internal view returns (string[] memory) {
        string memory jsonPath = string.concat(".", network, ".deployExecutors");
        return vm.parseJsonStringArray(json, jsonPath);
    }

    function _deployExecutor(string memory executorName) internal returns (address deployedAddress) {
        // check if target executor contract has been deployed before.
        deployedAddress = _getDeployedAddress(network, executorName);
        if (deployedAddress != address(0)) {
            console.log("Found existing %s at %s, deployment skipped.", executorName, deployedAddress);
            return deployedAddress;
        }

        string memory contractPath = string.concat(executorSrcPath, executorName, ".sol:", executorName);
        console.log("Loading contract from path: %s", contractPath);

        bytes memory bytecode = vm.getCode(contractPath);
        // get constructor arguments by contract name
        bytes memory constructorArgs = _getConstructArgsByName(executorName);

        DeploymentParams memory params = DeploymentParams({
            bytecode: bytecode,
            constructorArgs: constructorArgs,
            contractName: executorName,
            contractTag: network
        });
        // deploy
        deployedAddress = _deployContract(params);
        console.log("Deployed executor %s at %s", executorName, deployedAddress);
    }

    function _getConstructArgsByName(string memory executorName) internal view returns (bytes memory) {
        if (keccak256(abi.encodePacked(executorName)) == keccak256(abi.encodePacked("UniswapV3Executor"))) {
            return _getUniswapV3ExecutorArgs(executorName);
        } else if (keccak256(abi.encodePacked(executorName)) == keccak256(abi.encodePacked("AerodromeExecutor"))) {
            return _getAerodromeExecutorArgs(executorName);
        } else if (keccak256(abi.encodePacked(executorName)) == keccak256(abi.encodePacked("PancakeV3Executor"))) {
            return _getPancakeV3ExecutorArgs(executorName);
        } else {
            revert("Unknown executor type");
        }
    }

    function _getUniswapV3ExecutorArgs(string memory executorName) internal view returns (bytes memory) {
        string memory baseKey = _toBaseKey(executorName);

        string memory name = vm.parseJsonString(json, string.concat(baseKey, ".name"));
        uint256 swapGasEstimate = vm.parseJsonUint(json, string.concat(baseKey, ".swapGasEstimate"));
        uint256 quoteGasLimit = vm.parseJsonUint(json, string.concat(baseKey, ".quoteGasLimit"));
        address quoter = vm.parseJsonAddress(json, string.concat(baseKey, ".quoter"));
        address factory = vm.parseJsonAddress(json, string.concat(baseKey, ".factory"));
        uint24[] memory defaultFees = abi.decode(vm.parseJson(json, string.concat(baseKey, ".defaultFees")), (uint24[]));

        return abi.encode(name, swapGasEstimate, quoteGasLimit, quoter, factory, defaultFees);
    }

    function _getAerodromeExecutorArgs(string memory executorName) internal view returns (bytes memory) {
        string memory baseKey = _toBaseKey(executorName);

        string memory name = vm.parseJsonString(json, string.concat(baseKey, ".name"));
        address factory = vm.parseJsonAddress(json, string.concat(baseKey, ".factory"));
        uint256 swapGasEstimate = vm.parseJsonUint(json, string.concat(baseKey, ".swapGasEstimate"));

        return abi.encode(name, factory, swapGasEstimate);
    }

    function _getPancakeV3ExecutorArgs(string memory executorName) internal view returns (bytes memory) {
        string memory baseKey = _toBaseKey(executorName);

        string memory name = vm.parseJsonString(json, string.concat(baseKey, ".name"));
        uint256 swapGasEstimate = vm.parseJsonUint(json, string.concat(baseKey, ".swapGasEstimate"));
        uint256 quoteGasLimit = vm.parseJsonUint(json, string.concat(baseKey, ".quoteGasLimit"));
        address quoter = vm.parseJsonAddress(json, string.concat(baseKey, ".quoter"));
        address factory = vm.parseJsonAddress(json, string.concat(baseKey, ".factory"));
        uint24[] memory defaultFees = abi.decode(vm.parseJson(json, string.concat(baseKey, ".defaultFees")), (uint24[]));

        return abi.encode(name, swapGasEstimate, quoteGasLimit, quoter, factory, defaultFees);
    }

    function _toBaseKey(string memory executorName) internal view returns (string memory) {
        return string.concat(".", network, ".executors.", executorName, ".params");
    }
}
