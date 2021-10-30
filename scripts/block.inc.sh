#!/bin/bash

# get_block_devices
# Scans the system for block devices using lsblk, saves results to a json file
# Parameters:
# - $filename: path to file where results are stored. Default: /blockdevices.json
function get_block_devices () {
  local FILENAME=${1:-"/blockdevices.json"}

  lsblk --bytes --json --output=name,size,label,path,tran |         # Get the data from lsblk
    jq '.blockdevices[] .size /= 1024*1024*1024' |                  # Convert block size to GB
    jq '.blockdevices[] .size |= ceil' |                            # Round block size to integer
    jq '.blockdevices[] .children[]? .size /= 1024*1024*1024' |     # Convert child block size to GB
    jq '.blockdevices[] .children[]? .size |= ceil' |               # Round child block size to integer
    tee "$FILENAME" > /dev/null                                     # Save to file
}

# print_block_devices
# Prints the block devices to the console
# Parameters:
# - $filename: path to file where block device data is stored. Default: /blockdevices.json
function print_block_devices () {
  local FILENAME=${1:-"/blockdevices.json"}

  if [[ -f "$FILENAME" ]]; then
    cat "$FILENAME" |
      jq -r '[.blockdevices[] .path] | join(" ")'
  fi
}

# format_block_device
# Formats a block device. Creates MBR partition table with a single ext4 partition occupying 100% of the disk tagged with NODE_LABEL label.
# WARNING: This will erase all existing data on the device.
# Parameters:
# - $device: block device to be formatted
# - $node_label: initialized node disk label. Default: ethnode
function format_block_device () {
  local DEVICE="$1"
  local NODE_LABEL=${2:-"ethnode"}

  if [[ -n "$DEVICE" ]]; then
    echo "Formatting $DEVICE..."
    parted "$DEVICE" --script mklabel msdos mkpart primary ext4 1MiB 100%
    
    # mkfs.ext4 fails if run immediately after parted command. TODO: why?
    sleep 5
    
    local PARTITION=$(lsblk "$DEVICE" --json --output name,path | jq -r '.blockdevices[] .children[]? .path')
    echo "Creating ext4 partition: $PARTITION ..."
    mkfs.ext4 -F "$PARTITION"
    
    echo "Updating partition label to $NODE_LABEL..."
    e2label "$PARTITION" "$NODE_LABEL"

    # Same with e2label. TODO: why?
    sleep 5
  fi
}