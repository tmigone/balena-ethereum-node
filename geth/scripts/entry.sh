#!/bin/bash
# References:
# - https://askubuntu.com/questions/162434/how-do-i-find-out-usb-speed-from-a-terminal
# - https://askubuntu.com/questions/1103569/how-do-i-change-the-label-reported-by-lsblk
# - https://unix.stackexchange.com/questions/116664/map-physical-usb-device-path-to-the-bus-device-number-returned-by-lsusb

set -e

source "$(dirname $0)/block.inc.sh"
source "$(dirname $0)/eth.inc.sh"

FILENAME=${BLOCKDEVICES_FILENAME:-"/blockdevices.json"}
ETH_NODE_LABEL=${ETH_NODE_LABEL:-"ethnode"}
ETH_NODE_MOUNTPOINT=${ETH_NODE_MOUNTPOINT:-"/mnt/ethereum"}

rm -f "$FILENAME"
mkdir -p "$ETH_NODE_MOUNTPOINT"

echo "Fetching block device's data..."
get_block_devices "$FILENAME"
eth_validate_devices "$FILENAME"
echo "Devices found: $(print_block_devices $FILENAME)"

echo "Checking devices for an initialized node..."
ETH_NODE_DEVICE=$(eth_find_initialized_node "$FILENAME" "$ETH_NODE_LABEL")

if [[ -z "$ETH_NODE_DEVICE" ]]; then
  echo "Could not find an initialized node! Looking for a suitable block device to initialize..."

  CANDIDATE_DEVICES=($(eth_get_candidate_devices "$FILENAME"))
  echo "Candidate devices: ${CANDIDATE_DEVICES[@]}"

  for DEVICE in "${CANDIDATE_DEVICES[@]}"; do
    # Initialize
    echo "Initializing $DEVICE..."
    format_block_device "$DEVICE" "$ETH_NODE_LABEL"

    # Validate and check again
    get_block_devices "$FILENAME"
    eth_validate_devices "$FILENAME"
    ETH_NODE_DEVICE=$(eth_find_initialized_node "$FILENAME" "$ETH_NODE_LABEL")
    echo "eth_node_device: $ETH_NODE_DEVICE"

    if [[ -n "$ETH_NODE_DEVICE" ]]; then
      ETH_INIT="true"
      echo "Device $DEVICE was successfully initialized!"
      break
    else
      echo "Could not initialize $DEVICE!"
    fi
  done
fi

# Proceed only if a device was found
if [[ -n "$ETH_NODE_DEVICE" ]]; then
  echo "Mounting device: $ETH_NODE_DEVICE"
  mount "$ETH_NODE_DEVICE" "$ETH_NODE_MOUNTPOINT"
  date > "$ETH_NODE_MOUNTPOINT/last_mounted"

  if [[ -n "$ETH_INIT" ]]; then
    date > "$ETH_NODE_MOUNTPOINT/initialized"
  fi
else
  echo "Could not find a suitable disk to store node data. Exiting..."
  exit 1
fi

# geth default flags
GETH_NETWORK="${GETH_NETWORK:-mainnet}"
GETH_CACHE="${GETH_CACHE:-1024}"
GETH_SYNCMODE="${GETH_SYNCMODE:-fast}"

# If command starts with an option (--...), prepend geth
if [[ "${1#-}" != "$1" ]]; then
  set -- /usr/local/bin/geth "$@"
fi

# Set flags if we are running geth
if [[ "$1" == *"geth"* ]]; then
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
  echo "$@"
fi

exec "$@"