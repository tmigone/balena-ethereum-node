#!/bin/bash

function eth_find_initialized_node () {
  local FILENAME=${1:-"/blockdevices.json"}
  local NODE_LABEL=${2:-"ethnode"}

  if [[ -f "$FILENAME" ]]; then
    cat "$FILENAME" |
      jq -r ".blockdevices[] | select(.children[]?.label==\"$NODE_LABEL\") | .children[] .path"
  fi
}

# eth_validate_devices
# Validates block devices testing for capabilities as storage medium for an ethereum node
# Specifically tests for:
# - ethmeta.usb --> block device is of USB type
# - ethmeta.usb3 --> block device is capable of and connected to a USB3 port
# - ethmeta.size --> block device has at least MIN_DISK_SIZE gigabytes of storage
# Usage: get_block_devices_info $filename $min_disk_size
# Parameters:
# - $filename: path to file where results are stored. Default: /blockdevices.json
# - $min_disk_size: minimum disk size required (in GB). Default: 350 GB (required for ethereum mainnet as of Oct/2021)
function eth_validate_devices () {
  local FILENAME=${1:-"/blockdevices.json"}
  local MIN_DISK_SIZE=${2:-350}

  if [[ -f "$FILENAME" ]]; then
    cat "$FILENAME" |
      jq '.blockdevices[] += { ethmeta: { usb: false, usb3: false, size: false }}' |    # Add ethmeta tracking object
      jq '(.blockdevices[] | select(.tran=="usb") | .ethmeta.usb) |= true' |            # Validate ethmeta.usb
      jq "(.blockdevices[] | select(.size>=$MIN_DISK_SIZE) | .ethmeta.size) |= true" |  # Validate ethmeta.size
      tee "$FILENAME" > /dev/null                                                       # Save to file

    # Unfortunately get_block_devices (lsblk) can't tell us if a device is USB3 or not, so we have to do this manually...
    # TODO: is there a better way?
    for _device in $(cat "$FILENAME" | jq -r '.blockdevices[] .name'); do
      # Get BUS:DEVNUM from syspath: /sys/devices/pci0000:00/0000:00:14.0/usb2/2-2/2-2:1.0/host3/target3:0:0/3:0:0:0/block/sdb --> 2-2 --> 2:2
      local USB_BUS_DEVNUM=$(readlink -f "/sys/block/$_device" | awk -F/ '{print $7}' | sed 's/-/:/')

      if [[ -n "$USB_BUS_DEVNUM" ]]; then
        # Get USB version from lsusb's attribute "bcdUSB"
        local USB_VERSION=$(lsusb -v -s "$USB_BUS_DEVNUM" 2>/dev/null | grep bcdUSB | awk '{print $2}')
        
        if [[ -n "$USB_VERSION" ]]; then
          # Strip minor version, we don't care 
          local USB_MAJOR_VERSION=$(echo "$USB_VERSION" | awk -F'.' '{print $1}')

          if [[ $USB_MAJOR_VERSION -ge 3 ]]; then
            cat "$FILENAME" |
              jq "(.blockdevices[] | select(.name==\"$_device\") | .ethmeta.usb3) |= true" |    # Validate ethmeta.usb3
              tee "$FILENAME" > /dev/null                                                       # Save to file
          fi
        fi
      fi
    done
  fi 
}

function eth_get_candidate_devices () {
  local FILENAME=${1:-"/blockdevices.json"}

  if [[ -f "$FILENAME" ]]; then
    cat "$FILENAME" |
      jq -r '.blockdevices[] | select(.ethmeta.usb==true and .ethmeta.usb3==true and .ethmeta.size==true) | .path'
  fi
}

