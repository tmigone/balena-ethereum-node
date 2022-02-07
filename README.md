# ⟠ balena-ethereum-node ⟠

Run an ethereum node with one click! 🚀

This project makes deploying an ethereum node to a balenaOS device super simple. The bundle installs:
- Ethereum's go-client: [geth](https://geth.ethereum.org/)
- An [influxdb](https://www.influxdata.com/) database for storing metrics
- A [grafana](https://grafana.com/) dashboard for monitoring

## Supported architectures

The following device types and architectures are supported:
- Intel Nuc (amd64)
- Raspberry Pi 4 (aarch64) - WIP

__Note__: Geth [requirements](https://docs.ethhub.io/using-ethereum/ethereum-clients/geth/) specify a minimum of 4GB of RAM and 320GB of SSD disk space available in order to properly sync your node to ethereum's mainnet. In practice, as of February 2022, 320GB is nowhere near enough to run a full node. The initial sync will take up to 500GB, so if you want to have some leeway you'll want to run with at least 1TB of disk space.

## Installation

There are two ways of deploying this project depending on your needs:
- joining a public fleet of nodes via [balenaHub](https://hub.balena.io)
- creating your own private fleet of nodes using [balenaCloud](https://www.balena.io/cloud/)

### balenaHub

balenaHub allows you to join an existing fleet of devices running this project. Deployment is simple, you just download and flash the image to your device and you're good to go. As you'll be joining an open fleet you won't have the same privileges you would have if you were running your own fleet. The fleet owner controls when updates are released and what configuration the devices run with. On the flip side, you won't need to create an account to join an open fleet. If you want to create and run your own private fleet check out the balenaCloud alternative below.

Read more about balenaHub and open fleets here: https://hub.balena.io/what-is-balenahub.
To deploy to your device using balenaHub visit: https://hub.balena.io/tmigone/balena-ethereum-node/

Once your device is done downloading the application, you can access the grafana dashboard to view it's metrics on: `http://geth.local` or `http://geth` depending on your machine's operative system.

### balenaCloud

If you want to create your own private fleet you can do so using balenaCloud. This will let you control when to update your nodes, what specific configuration you want the node to run with and will give you all the perks of the balenaCloud dashboard: access to device metrics and logs, ssh access, remote management capabilities, etc. 

If you are not familiar with balenaCloud you'll need to sign up for a free account [here](https://dashboard.balena-cloud.com/signup) and probably run through the [getting started guide](https://www.balena.io/docs/learn/getting-started/raspberrypi3/nodejs/) before deploying this project. The setup is fairly straightforward, it should take you about 15 minutes to get everything started.

You can then deploy this project to your fleet clicking the button below:

[![deploy button](https://balena.io/deploy.svg)](https://dashboard.balena-cloud.com/deploy?repoUrl=https://github.com/tmigone/balena-ethereum-node&defaultDeviceType=intel-nuc)


## Configuration

The following environment variables can be used to customize your node. Read more about how to set variables in balenaCloud here: https://www.balena.io/docs/learn/manage/variables/. Note that they correspond to `geth` command line options so always check their [documentation](https://geth.ethereum.org/docs/interface/command-line-options) for up to date information.

__Note__: This only applies to balenaCloud deployment as only the fleet owner can modify these variables.

| Variable  | Description | Geth option | Default |
| ------------- | ------------- | ------------- | ------------- |
| GETH_NETWORK | Which network to connect the node to. Available networks: `mainnet`, `goerli`, `rinkeby`, `ropsten`, `sepolia` | One of: <ul><li>`--mainnet`</li><li>`--goerli`</li><li>`--rinkeby`</li><li>`--ropsten`</li><li>`--sepolia`</li></ul> | `mainnet` |
| GETH_CACHE | Megabytes of memory allocated to internal caching. Can take any numeric value. | `--cache` | `1024` |
| GETH_SYNCMODE | Blockchain sync mode: `snap`, `full` or `light`. | `--syncmode` | `snap` |
| GETH_RPC_HTTP | Enable the HTTP-RPC server. Either `true` or `false` | Bundles: <ul><li>`--http`</li><li>`--http.address 0.0.0.0`</li><li>`--http.corsdomain "*"`</li><li>`--http.api "$GETH_RPC_API"`</li></ul> | `true` |
| GETH_RPC_WS | Enable the WS-RPC server. Either `true` or `false` | Bundles: <ul><li>`--ws`</li><li>`--ws.address 0.0.0.0`</li><li>`--ws.origins "*"`</li><li>`--ws.api "$GETH_RPC_API"`</li></ul> | `true` |
| GETH_RPC_API |  API's offered over the HTTP-RPC and WS-RPC interfaces if enabled. | Bundles: <ul><li>`--http.apis <value>`</li><li>`--ws.apis <value>`</li></ul> | `eth,net,web3` |


## References
- https://greg.jeanmart.me/2020/02/23/running-an-ethereum-full-node-on-a-raspberrypi-4-/
- https://core-geth.org/setup-on-raspberry-pi
- https://ethereum.org/en/developers/tutorials/monitoring-geth-with-influxdb-and-grafana/
- https://grafana.com/grafana/dashboards/13877