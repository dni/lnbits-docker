#!/bin/sh
export COMPOSE_PROJECT_NAME=lnbits-legend

bitcoin-cli-sim(){
  docker exec lnbits-legend-bitcoind-1 bitcoin-cli -rpcuser=lnbits -rpcpassword=lnbits -regtest $@
}

# args(i, cmd)
lightning-cli-sim() {
  i=$1
  shift # shift first argument so $@
  docker exec lnbits-legend-clightning-$i lightning-cli --network regtest $@
}

# args(i, cmd)
lncli-sim() {
  i=$1
  shift # shift first argument so $@
  docker exec lnbits-legend-lnd-$i lncli --network regtest --rpcserver=lnd:10009 $@
}

# args(i)
fund_clightning_node() {
  address=$(lightning-cli-sim $1 newaddr | jq -r .bech32)
  echo "funding: $address on node: $1"
  bitcoin-cli-sim -named sendtoaddress address=$address amount=10 fee_rate=100 2> /dev/null
}
# args(i)
fund_lnd_node() {
  address=$(lncli-sim 1 newaddress p2wkh | jq -r .address)
  echo "funding: $address on node: $1"
  bitcoin-cli-sim -named sendtoaddress address=$address amount=10 fee_rate=100 2> /dev/null
}

# args(i, j)
connect_clightning_node() {
  pubkey=$(lightning-cli-sim $2 getinfo | jq -r '.id')
  lightning-cli-sim $1 connect $pubkey@lnbits-legend-clightning-$2
}

lnbits-regtest-start(){
  lnbits-regtest-stop
  docker compose up --scale clightning=3 -d
}
lnbits-regtest-start-log(){
  lnbits-regtest-stop
  docker compose up --scale clightning=3
}
lnbits-regtest-stop(){
  docker compose down --volumes
  sudo rm -rf ./data/lnd ./data/boltz/boltz.db
  mkdir ./data/lnd

}
lnbits-regtest-restart(){
  lnbits-regtest-stop
  lnbits-regtest-start
}

lnbits-regtest-init(){
  echo "init_bitcoin_wallet..."
  bitcoin-cli-sim createwallet lnbits || bitcoin-cli-sim loadwallet lnbits
  bitcoin-cli-sim -generate 150
  # create 10 UTXOs for each node
  for i in 0 1 2 3 4 5 6 7 8 9; do
    fund_clightning_node 1
    fund_clightning_node 2
    fund_clightning_node 3
    fund_lnd_node 1
  done
  bitcoin-cli-sim -generate 3
  sleep 20

  # connect all clightning nodes as peers with each other
  # and open channels 1 -> 2, 2 -> 3, 3 -> 1
  channel_size=16000000 # 0.016 btc
  balance_size_msat=7000000000 # 0.07 btc
  peer1=$(connect_clightning_node 1 2 | jq -r '.id')
  connect_clightning_node 1 3
  lightning-cli-sim 1 fundchannel -k id=$peer1 amount=$channel_size push_msat=$balance_size_msat
  peer2=$(connect_clightning_node 2 3 | jq -r '.id')
  connect_clightning_node 2 1
  lightning-cli-sim 2 fundchannel -k id=$peer2 amount=$channel_size push_msat=$balance_size_msat
  connect_clightning_node 3 2
  lightning-cli-sim 3 fundchannel -k id=$(connect_clightning_node 3 1 | jq -r '.id') amount=$channel_size push_msat=$balance_size_msat

  # lnd node for boltz
  lncli-sim 1 connect $(lightning-cli-sim 1 getinfo | jq -r '.id')@lnbits-legend-clightning-1
  lncli-sim 1 openchannel $(lncli-sim 1 listpeers | jq -r '.peers[0].pub_key') $channel_size 8000000

  bitcoin-cli-sim -generate 1
}

