#!/bin/bash
# References:
# - https://askubuntu.com/questions/162434/how-do-i-find-out-usb-speed-from-a-terminal
# - https://askubuntu.com/questions/1103569/how-do-i-change-the-label-reported-by-lsblk
# - https://unix.stackexchange.com/questions/116664/map-physical-usb-device-path-to-the-bus-device-number-returned-by-lsusb
set -e

source block.inc.sh 
source eth.inc.sh 

FILENAME=${1:-"/blockdevices.json"}
ETH_NODE_LABEL=${2:-"ethnode"}
ETH_NODE_MOUNTPOINT=${3:-"/mnt/ethereum"}

rm -f "$FILENAME"
mkdir -p "$ETH_NODE_MOUNTPOINT"

echo "Fetching block device's data..."
get_block_devices "$FILENAME"
eth_validate_devices "$FILENAME"
echo "Devices found: $(print_block_devices $FILENAME)"

echo "Checking devices for an initialized node..."
ETH_NODE_DEVICE=$(eth_find_initialized_node "$FILENAME" "$ETH_NODE_LABEL")

if [[ -n "$ETH_NODE_DEVICE" ]]; then
  echo "Found initialized ethereum node at $ETH_NODE_DEVICE"
  mount "$ETH_NODE_DEVICE" "$ETH_NODE_MOUNTPOINT"
  date > "$ETH_NODE_MOUNTPOINT/last_mounted"
else
  echo "Could not find an initialized node! Looking for a suitable block device to initialize..."
  CANDIDATE_DEVICES=($(eth_get_candidate_devices "$FILENAME"))
  echo "Candidate devices: ${CANDIDATE_DEVICES[@]}"
  for DEVICE in "${CANDIDATE_DEVICES[@]}"; do
    # Initialize
    echo "Initializing $DEVICE..."
    format_block_device "$DEVICE" "$ETH_NODE_LABEL"

    # Validate
    get_block_devices "$FILENAME"
    eth_validate_devices "$FILENAME"
    ETH_NODE_DEVICE=$(eth_find_initialized_node "$FILENAME" "$ETH_NODE_LABEL")

    if [[ -n "$ETH_NODE_DEVICE" ]]; then
      mount "$ETH_NODE_DEVICE" "$ETH_NODE_MOUNTPOINT"
      date > "$ETH_NODE_MOUNTPOINT/initialized"
      date > "$ETH_NODE_MOUNTPOINT/last_mounted"
      echo "Device $DEVICE was successfully initialized!"
      break
    else
      echo "Could not initialize $DEVICE!"
    fi
  done
fi

