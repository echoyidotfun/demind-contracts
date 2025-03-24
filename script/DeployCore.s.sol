// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "./DeployBase.s.sol";
import "src/interfaces/IWrappedNative.sol";
import "test/utils/MockWETH.sol";

/// @notice scripts for executor deployments, which is previous step for router deployments
contract DeployCore is DeployBase {
    string public network;

    string public jsonConfig = vm.readFile(jsonConfigPath);
    string public executorSrcPath = string.concat(vm.projectRoot(), "/src/executors/");
    string public routerSrcPath = string.concat(vm.projectRoot(), "/src/router/");

    function run() external {
        network = vm.envOr("NETWORK", string("base_sepolia"));
        console.log("Deploying all whitelisted executors on network: %s", network);
        // 1. deploy all whitelisted executors
        string[] memory executorNames = _getNetworkExecutors();
        address[] memory executorAddresses = new address[](executorNames.length);
        for (uint256 i = 0; i < executorNames.length; i++) {
            executorAddresses[i] = _deployExecutor(executorNames[i]);
        }
        // 2. deploy router
        _deployRouter(executorAddresses);
    }

    function _deployRouter(address[] memory executors) internal {
        string memory routerName = vm.parseJsonString(jsonConfig, string.concat(".", network, ".router.name"));
        bytes memory bytecode = vm.getCode(string.concat(routerSrcPath, routerName, ".sol:", routerName));

        string memory baseKey = string.concat(".", network, ".router.params");
        address[] memory trustedTokens = vm.parseJsonAddressArray(jsonConfig, string.concat(baseKey, ".trustedTokens"));

        address feeClaimer = vm.parseJsonAddress(jsonConfig, string.concat(baseKey, ".feeClaimer"));
        address wrappedNative;
        if (keccak256(abi.encodePacked(network)) == keccak256(abi.encodePacked("anvil"))) {
            IWrappedNative weth = new MockWETH();
            wrappedNative = address(weth);
        } else {
            wrappedNative = vm.parseJsonAddress(jsonConfig, string.concat(baseKey, ".wrappedNative"));
        }

        bytes memory constructorArgs = abi.encode(executors, trustedTokens, feeClaimer, wrappedNative);
        DeploymentParams memory params = DeploymentParams({
            bytecode: bytecode,
            constructorArgs: constructorArgs,
            contractName: routerName,
            contractTag: "router",
            network: network
        });
        _deployContract(params);
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
            contractTag: "executor",
            network: network
        });
        // deploy
        deployedAddress = _deployContract(params);
    }

    function _getNetworkExecutors() internal view returns (string[] memory) {
        string memory jsonPath = string.concat(".", network, ".deployExecutors");
        return vm.parseJsonStringArray(jsonConfig, jsonPath);
    }

    function _getConstructArgsByName(string memory executorName) internal view returns (bytes memory) {
        if (keccak256(abi.encodePacked(executorName)) == keccak256(abi.encodePacked("UniswapV3Executor"))) {
            return _getUniswapV3ExecutorArgs(executorName);
        } else if (keccak256(abi.encodePacked(executorName)) == keccak256(abi.encodePacked("AerodromeExecutor"))) {
            return _getAerodromeExecutorArgs(executorName);
        } else if (keccak256(abi.encodePacked(executorName)) == keccak256(abi.encodePacked("PancakeV3Executor"))) {
            return _getPancakeV3ExecutorArgs(executorName);
        } else if (keccak256(abi.encodePacked(executorName)) == keccak256(abi.encodePacked("ShadowV2Executor"))) {
            return _getRamsesV2LikeExecutorArgs(executorName);
        } else {
            revert("Unknown executor type");
        }
    }

    function _getUniswapV3ExecutorArgs(string memory executorName) internal view returns (bytes memory) {
        string memory baseKey = _toBaseKey(executorName);

        string memory name = vm.parseJsonString(jsonConfig, string.concat(baseKey, ".name"));
        uint256 swapGasEstimate = vm.parseJsonUint(jsonConfig, string.concat(baseKey, ".swapGasEstimate"));
        uint256 quoteGasLimit = vm.parseJsonUint(jsonConfig, string.concat(baseKey, ".quoteGasLimit"));
        address quoter = vm.parseJsonAddress(jsonConfig, string.concat(baseKey, ".quoter"));
        address factory = vm.parseJsonAddress(jsonConfig, string.concat(baseKey, ".factory"));
        uint24[] memory defaultFees =
            abi.decode(vm.parseJson(jsonConfig, string.concat(baseKey, ".defaultFees")), (uint24[]));

        return abi.encode(name, swapGasEstimate, quoteGasLimit, quoter, factory, defaultFees);
    }

    function _getAerodromeExecutorArgs(string memory executorName) internal view returns (bytes memory) {
        string memory baseKey = _toBaseKey(executorName);

        string memory name = vm.parseJsonString(jsonConfig, string.concat(baseKey, ".name"));
        address factory = vm.parseJsonAddress(jsonConfig, string.concat(baseKey, ".factory"));
        uint256 swapGasEstimate = vm.parseJsonUint(jsonConfig, string.concat(baseKey, ".swapGasEstimate"));

        return abi.encode(name, factory, swapGasEstimate);
    }

    function _getPancakeV3ExecutorArgs(string memory executorName) internal view returns (bytes memory) {
        string memory baseKey = _toBaseKey(executorName);

        string memory name = vm.parseJsonString(jsonConfig, string.concat(baseKey, ".name"));
        uint256 swapGasEstimate = vm.parseJsonUint(jsonConfig, string.concat(baseKey, ".swapGasEstimate"));
        uint256 quoteGasLimit = vm.parseJsonUint(jsonConfig, string.concat(baseKey, ".quoteGasLimit"));
        address quoter = vm.parseJsonAddress(jsonConfig, string.concat(baseKey, ".quoter"));
        address factory = vm.parseJsonAddress(jsonConfig, string.concat(baseKey, ".factory"));
        uint24[] memory defaultFees =
            abi.decode(vm.parseJson(jsonConfig, string.concat(baseKey, ".defaultFees")), (uint24[]));

        return abi.encode(name, swapGasEstimate, quoteGasLimit, quoter, factory, defaultFees);
    }

    function _getRamsesV2LikeExecutorArgs(string memory executorName) internal view returns (bytes memory) {
        string memory baseKey = _toBaseKey(executorName);

        string memory name = vm.parseJsonString(jsonConfig, string.concat(baseKey, ".name"));
        address factory = vm.parseJsonAddress(jsonConfig, string.concat(baseKey, ".factory"));
        uint256 swapGasEstimate = vm.parseJsonUint(jsonConfig, string.concat(baseKey, ".swapGasEstimate"));

        return abi.encode(name, factory, swapGasEstimate);
    }

    function _toBaseKey(string memory executorName) internal view returns (string memory) {
        return string.concat(".", network, ".executors.", executorName, ".params");
    }
}
