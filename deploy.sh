#!/bin/bash

# check args
if [ -z "$1" ]; then
  echo "Usage: ./deploy.sh <network>"
  echo "Supported networks: base, base_sepolia"
  exit 1
fi

NETWORK=$1

# 设置环境变量
export NETWORK=$NETWORK

# 执行部署
echo "Deploying to $NETWORK..."
forge script script/DeployCore.s.sol --rpc-url $NETWORK --broadcast --verify