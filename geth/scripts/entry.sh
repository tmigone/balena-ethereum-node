#!/bin/bash
# References:
# - https://askubuntu.com/questions/162434/how-do-i-find-out-usb-speed-from-a-terminal
# - https://askubuntu.com/questions/1103569/how-do-i-change-the-label-reported-by-lsblk
# - https://unix.stackexchange.com/questions/116664/map-physical-usb-device-path-to-the-bus-device-number-returned-by-lsusb

set -e

source "$(dirname $0)/block.inc.sh"
source "$(dirname $0)/eth.inc.sh"

FILENAME=${BLOCKDEVICES_FILENAME:-"/app/blockdevices.json"}
ETH_NODE_LABEL=${ETH_NODE_LABEL:-"ethnode"}
ETH_NODE_MOUNTPOINT=${ETH_NODE_MOUNTPOINT:-"/mnt/ethereum"}
ETH_ANCIENT_NODE_LABEL=${ETH_ANCIENT_NODE_LABEL:-"ethancient"}
ETH_ANCIENT_NODE_MOUNTPOINT=${ETH_ANCIENT_NODE_MOUNTPOINT:-"/mnt/ethereum-ancient"}

rm -f "$FILENAME"
mkdir -p "$ETH_NODE_MOUNTPOINT"
mkdir -p "$ETH_ANCIENT_NODE_MOUNTPOINT"

echo "--- Block devices ---"
echo "Fetching block device's data..."
get_block_devices "$FILENAME"
eth_validate_devices "$FILENAME"
echo "Found block devices: $(print_block_devices $FILENAME)"

echo -e "\n--- Geth main storage node ---"
CANDIDATES=($(eth_get_onboard_node_candidates "$FILENAME"))

if [[ -n "$CANDIDATES" ]]; then
  # MAIN NODE --> ONBOARD
  ETH_NODE_MOUNTPOINT="/geth"
  ETH_NODE_LABEL="/geth"
  echo "Main drive is suitable, using it as geth node"
else
  # MAIN NODE --> USB
  echo "Checking devices for an initialized node..."
  ETH_NODE_DEVICE=$(eth_find_usb_node "$FILENAME" "$ETH_NODE_LABEL")

  if [[ -z "$ETH_NODE_DEVICE" ]]; then
    echo "Could not find an initialized node!"
    eth_usb_node_initialize "$FILENAME" "$ETH_NODE_LABEL"
  else
    echo "Found initialized node at $ETH_NODE_DEVICE"
  fi

  ETH_NODE_DEVICE=$(eth_find_usb_node "$FILENAME" "$ETH_NODE_LABEL")

  if [[ -n "$ETH_NODE_DEVICE" ]]; then
    mount_block_device "$ETH_NODE_DEVICE" "$ETH_NODE_MOUNTPOINT"
  else
    echo "Could not find a suitable usb disk to initialize node. Exiting..."
    exit 1
  fi
fi

echo "Ethereum node: $ETH_NODE_DEVICE@$ETH_NODE_MOUNTPOINT"

# ANCIENT NODE --> USB
echo -e "\n--- Geth ancient storage node ---"
echo "Checking devices for an initialized ancient node..."
ETH_ANCIENT_NODE_DEVICE=$(eth_find_usb_node "$FILENAME" "$ETH_ANCIENT_NODE_LABEL")

if [[ -z "$ETH_ANCIENT_NODE_DEVICE" ]]; then
  echo "Could not find an initialized node!"
  eth_usb_node_initialize "$FILENAME" "$ETH_ANCIENT_NODE_LABEL" "$ETH_NODE_LABEL"
else
  echo "Found initialized node at $ETH_ANCIENT_NODE_LABEL"
fi

ETH_ANCIENT_NODE_DEVICE=$(eth_find_usb_node "$FILENAME" "$ETH_ANCIENT_NODE_LABEL")

if [[ -n "$ETH_ANCIENT_NODE_DEVICE" ]]; then
  mount_block_device "$ETH_ANCIENT_NODE_DEVICE" "$ETH_ANCIENT_NODE_MOUNTPOINT"
  echo -e "\nEthereum ancient node: $ETH_ANCIENT_NODE_DEVICE@$ETH_ANCIENT_NODE_MOUNTPOINT"
else
  echo -e "\nCould not find a suitable usb disk to initialize an ancient node, skipping..."
fi

# geth default flags
GETH_NETWORK="${GETH_NETWORK:-mainnet}"
GETH_CACHE="${GETH_CACHE:-1024}"
GETH_SYNCMODE="${GETH_SYNCMODE:-snap}"
GETH_RPC_HTTP="${GETH_RPC_HTTP:-true}"
GETH_RPC_WS="${GETH_RPC_WS:-true}"
GETH_RPC_API="${GETH_RPC_API:-eth,net,web3}"

# If command starts with an option (--...), prepend geth
if [[ "${1#-}" != "$1" ]]; then
  set -- /usr/local/bin/geth "$@"
fi

# Set flags if we are running geth
if [[ "$1" == *"geth" ]]; then
  shift
  set -- /usr/local/bin/geth \
    "--$GETH_NETWORK" \
    --cache "$GETH_CACHE" \
    --syncmode "$GETH_SYNCMODE" \
    --datadir "$ETH_NODE_MOUNTPOINT" \
    --metrics \
    --metrics.influxdb \
    --metrics.influxdb.endpoint "http://influxdb:8086" \
    --metrics.influxdb.database "balena" \
    --metrics.influxdb.username "geth" \
    "$@"

  # Ancient
  if [[ -n "$ETH_ANCIENT_NODE_DEVICE" ]]; then
    set -- "$@" \
      --datadir.ancient "$ETH_ANCIENT_NODE_MOUNTPOINT"
  fi

  # HTTP-RPC
  if [[ "$GETH_RPC_HTTP" == true ]]; then
    set -- "$@" \
      --http \
      --http.addr "0.0.0.0" \
      --http.corsdomain "*" \
      --http.api "$GETH_RPC_API"
  fi

  # WS-RPC
  if [[ "$GETH_RPC_HTTP" == true ]]; then
    set -- "$@" \
      --ws \
      --ws.addr "0.0.0.0" \
      --ws.origins "*" \
      --ws.api "$GETH_RPC_API"
  fi
fi

echo -e "\n--- Geth ---"
echo "Running geth with the following parameters:"
echo "$@"

# Don't actually start geth if we are on local mode
if [[ "$BALENA_APP_NAME" == "localapp" ]]; then
  balena-idle
fi

# Prometheus node exporter
# This should be on a separate container but we can't mount USB drives in both
SCRAPE_PORT=${SCRAPE_PORT:-9100}

node_exporter \
  --log.level=error \
  --web.listen-address=":$SCRAPE_PORT" \
  --collector.disable-defaults \
  --collector.filesystem &
  # --collector.filesystem.ignored-mount-points="^/(dev|proc|sys|var/lib/docker/.+|etc|tmp)($|/)" &

exec "$@"
