#!/bin/bash

# get_block_devices $filename
# Scans the system for block devices using lsblk, saves results to a json file
# Usage: get_block_devices $filename
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


function print_block_devices () {
  local FILENAME=${1:-"/blockdevices.json"}

  if [[ -f "$FILENAME" ]]; then
    cat "$FILENAME" |
      jq -r '[.blockdevices[] .path] | join(" ")'
  fi
}

function format_block_device () {
  local DEVICE="$1"
  local NODE_LABEL=${2:-"ethnode"}

  if [[ -n "$DEVICE" ]]; then
    echo "Formatting $DEVICE..."
    parted "$DEVICE" --script mklabel msdos mkpart primary ext4 1MiB 100%
    
    echo "Creating ext4 partition..."
    local PARTITION=$(lsblk "$DEVICE" --json --output name,path | jq -r '.blockdevices[] .children[]? .path')
    mkfs.ext4 -F "$PARTITION"
    
    echo "Updating partition label to $NODE_LABEL..."
    e2label "$PARTITION" "$NODE_LABEL"
  fi
}