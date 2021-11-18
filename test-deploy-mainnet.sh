#! /bin/bash

export ETH_GAS=5000000
export ETH_GAS_PRICE=$(seth --to-wei 500 gwei)
export ETH_PRIO_FEE=$(seth --to-wei 3 gwei)

if [[ $ETH_FROM -eq 0 ]] ; then
    echo "You need to set ETH_FROM to an address from Hardhat fork."
    echo "You should also use `ethsign import` to import the private key from hardhat for the address."
    exit 1
fi

export DAPP_TEST_ADDRESS=$ETH_FROM

echo "Deploying contracts with script"
deploy_output=$(./scripts/deploy-mainnet.sh)
echo "Deployment completed"

deploy_output=${deploy_output//": "/"="}
export UniswapV2CalleeDai=$(echo $deploy_output| cut -d' ' -f 1 | cut -d'=' -f 2)
export UniswapV2LpTokenCalleeDai=$(echo $deploy_output| cut -d' ' -f 2 | cut -d'=' -f 2)
export UniswapV3Callee=$(echo $deploy_output| cut -d' ' -f 3 | cut -d'=' -f 2)
export WstETHCurveUniv3Callee=$(echo $deploy_output| cut -d' ' -f 4 | cut -d'=' -f 2)

for file in ./src/test/*.sol
do
    new_file="./src/test/deploy-$(echo $file | cut -d'/' -f 4)"
    cat $file                                                                                                                    \
      | sed -E "s|new UniswapV2CalleeDai\([a-zA-Z0-9(), ]*\)|UniswapV2CalleeDai\($UniswapV2CalleeDai\)|g"                        \
      | sed -E "s|new UniswapV2LpTokenCalleeDai\([a-zA-Z0-9(), ]*\)|UniswapV2LpTokenCalleeDai\($UniswapV2LpTokenCalleeDai\)|g"   \
      | sed -E "s|new UniswapV3Callee\([a-zA-Z0-9(), ]*\)|UniswapV3Callee\($UniswapV3Callee\)|g"                                 \
      | sed -E "s|new WstETHCurveUniv3Callee\([a-zA-Z0-9(), ]*\)|WstETHCurveUniv3Callee\($WstETHCurveUniv3Callee\)|g"            \
      >> "$new_file"
done

if [[ $# -eq 0 ]] ; then
    dapp --use solc:0.6.12 test --rpc --verbosity 3 -m "deploy-"
else
    dapp --use solc:0.6.12 test --rpc --verbosity 3 -m ${1}
fi

for file in ./src/test/deploy-*.sol
do
    rm $file
done