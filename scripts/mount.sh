#!/bin/bash
# References:
# - https://askubuntu.com/questions/162434/how-do-i-find-out-usb-speed-from-a-terminal
# - https://askubuntu.com/questions/1103569/how-do-i-change-the-label-reported-by-lsblk
# - https://unix.stackexchange.com/questions/116664/map-physical-usb-device-path-to-the-bus-device-number-returned-by-lsusb


FILENAME=${1:-"/blockdevices.json"}
rm -f "$FILENAME"

get_block_devices "$FILENAME"
eth_validate_devices "$FILENAME"

# eth_validate_devices
# Validates block devices testing for capabilities as storage medium for an ethereum node
# Specifically tests for:
# - ethmeta.usb --> block device is of USB type
# - ethmeta.usb3 --> block device is capable of and connected to a USB3 port
# - ethmeta.size --> block device has at least MIN_DISK_SIZE gigabytes of storage
# Usage: get_block_devices_info $filename $min_disk_size
# Parameters:
# - $filename: path to file where results are stored. Default: /blockdevices.json
# - $min_disk_size: minimum disk size required. Default: 350 GB (required for ethereum mainnet as of Oct/2021)
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
      jq '[.blockdevices[] | select(.ethmeta.usb==false and .ethmeta.usb3==false and .ethmeta.size==false)][0]'
  fi
}

# get_block_devices $filename
# Scans the system for block devices using lsblk, saves results to a json file
# Usage: get_block_devices $filename
# Parameters:
# - $filename: path to file where results are stored. Default: /blockdevices.json
function get_block_devices () {
  local FILENAME=${1:-"/blockdevices.json"}

  lsblk --bytes --json --output=name,size,label,path,tran |                           # Get the data from lsblk
    jq 'del(.blockdevices[] .children)' |                                             # Remove block children[]
    jq '.blockdevices[] .size /= 1024*1024*1024' |                                    # Convert block size to GB
    jq '.blockdevices[] .size |= floor' |                                             # Round block size to integer
    tee "$FILENAME" > /dev/null                                                       # Save to file
}


