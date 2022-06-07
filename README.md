# usage

```console
source docker-scripts.sh
# start docker-compose with logs
lnbits-regtest-start-log
# start docker-compose in background
lnbits-regtest-start

# initialize blockchain,
# fund lightning wallets
# connect peers
# create channels
# balance channels
lnbits-regtest-init

# use bitcoin core, mine a block
bitcoin-cli-sim -generate 1

# use c-lightning nodes
lightning-cli-sim 1 newaddr # use node 1
lightning-cli-sim 2 getinfo # use node 2
lightning-cli-sim 3 getinfo | jq -r '.bech32' # use node 3

# use lnd nodes
lncli-sim 1 newaddr p2wsh
```
