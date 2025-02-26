// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

abstract contract DeployBase is Script {
    struct DeploymentParams {
        bytes bytecode;
        bytes constructorArgs;
        string contractName;
        string contractTag;
    }

    string public basePath;
    string public jsonConfigPath;
    string public jsonOutputPath;

    uint256 public deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address public deployer = vm.rememberKey(deployerPrivateKey);
    string public configFilename = vm.envString("CONFIG_FILENAME");
    string public outputFilename = vm.envString("OUTPUT_FILENAME");

    constructor() {
        string memory root = vm.projectRoot();
        basePath = string.concat(root, "/script/deployments/");
        jsonConfigPath = string.concat(basePath, configFilename);
        jsonOutputPath = string.concat(basePath, outputFilename);

        try vm.readFile(jsonOutputPath) {
            // 文件存在，不需要做任何事情
        } catch {
            // 文件不存在，创建一个空的JSON对象
            vm.writeFile(jsonOutputPath, "{}");
        }
    }

    /// @dev deploy contract by contract bytecode and constructor args
    function _deployContract(DeploymentParams memory params) internal returns (address deployAddress) {
        bytes memory creationCode = abi.encodePacked(params.bytecode, params.constructorArgs);

        vm.startBroadcast();
        assembly {
            deployAddress := create(0, add(creationCode, 0x20), mload(creationCode))
            if iszero(deployAddress) { revert(0, 0) }
        }
        vm.stopBroadcast();

        // save deployment information
        _saveDeployedAddress(params.contractTag, params.contractName, deployAddress);
    }

    function _saveDeployedAddress(string memory tag, string memory contractName, address contractAddress) internal {
        string memory jsonPath = string.concat(".", tag);
        vm.writeJson(vm.serializeAddress(tag, contractName, contractAddress), jsonOutputPath, jsonPath);
    }

    function _getDeployedAddress(string memory tag, string memory contractName) internal view returns (address) {
        string memory addrKey = string.concat(".", tag, ".", contractName);
        try vm.parseJsonAddress(vm.readFile(jsonOutputPath), addrKey) returns (address deployedAddress) {
            return deployedAddress;
        } catch {
            return address(0);
        }
    }
}
