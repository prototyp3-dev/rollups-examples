#!/bin/bash

if [ $# != 4 ]
then
    echo "Missing arguments: network, rpc-url, public-key, private-key"
    exit 0
fi

INPUT_BOX_ADDR="0x5a723220579C0DCb8C9253E6b4c62e572E379945"

NETWORK=$1
RPC_URL=$2
PUBLIC_KEY=$3
PRIVATE_KEY=$4

AUTHORITY_PATH="deployments/$NETWORK/authority/$PUBLIC_KEY"

mkdir -p $AUTHORITY_PATH


if [ ! -f "$AUTHORITY_PATH/authority.txt" ]
then
    echo "Deploying Authority contract..."

    # deploy Authorithy.sol
    docker run viannaarthur/authority-deployer "forge create --rpc-url $RPC_URL --constructor-args $PUBLIC_KEY $INPUT_BOX_ADDR --private-key $PRIVATE_KEY ./src/Authority.sol:Authority" | tail -n 3 > $AUTHORITY_PATH/authority.txt

    cat "$AUTHORITY_PATH/authority.txt"
fi

AUTHORITY_ADDR=$(cat $AUTHORITY_PATH/authority.txt | grep "Deployed to" | cut -d ":" -f 2 | cut -d " " -f 2)


if [ ! -f "$AUTHORITY_PATH/history.txt" ]
then
    echo "Deploying History contract..."

    # deploy History.sol
    docker run viannaarthur/authority-deployer "forge create --rpc-url $RPC_URL --constructor-args $AUTHORITY_ADDR --private-key $PRIVATE_KEY src/History.sol:History" | tail -n 3 > $AUTHORITY_PATH/history.txt

    cat "$AUTHORITY_PATH/history.txt"

    HISTORY_ADDR=$(cat $AUTHORITY_PATH/history.txt | grep "Deployed to" | cut -d ":" -f 2)

    # set Authority's History to the one deployed.
    docker run viannaarthur/authority-deployer "cast send --private-key $PRIVATE_KEY $AUTHORITY_ADDR \"setHistory(address)\" $HISTORY_ADDR --rpc-url $RPC_URL"
fi


NETWORK_FILE="deployments/$NETWORK/$NETWORK.json"
if [ ! -f "$NETWORK_FILE" ]
then
    AUX_FILE="deployments/$NETWORK/aux.json"
    wget https://github.com/cartesi/rollups/blob/main/onchain/rollups/export/abi/sepolia.json?raw=True -O $AUX_FILE


    DEFAULT_AUTHORITY_ADDR="0x35EC7d70cAff883844d94b54cD19634fFAb5d8CC"
    sed -e "s/$DEFAULT_AUTHORITY_ADDR/$AUTHORITY_ADDR/g" ${AUX_FILE} > ${NETWORK_FILE}
    
    rm ${AUX_FILE}
fi