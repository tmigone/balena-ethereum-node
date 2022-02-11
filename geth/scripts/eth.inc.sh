#!/bin/bash

# eth_validate_devices
# Validates block devices testing for capabilities as storage medium for an ethereum node
# Specifically tests for:
# - ethmeta.usb --> block device is of USB type
# - ethmeta.size --> block device has at least MIN_DISK_SIZE gigabytes of storage
# - ethmeta.ssd --> block device is of type SSD
# - ethmeta.usb3 --> block device is capable of and connected to a USB3 port (implemented but unreliable) 
# - ethmeta.wspeed --> block device can write data faster than MIN_WRITE_SPEED (not implemented)
# - ethmeta.rspeed --> block device can read data faster than MIN_READ_SPEED (not implemented)
# Parameters:
# - $filename: path to file where blockdevice data is stored. Default: /blockdevices.json
# - $min_disk_size: minimum disk size required (in GB). Default: 350 GB (required for ethereum mainnet as of Oct/2021)
function eth_validate_devices () {
  local FILENAME=${1:-"/blockdevices.json"}
  local MIN_DISK_SIZE=${2:-800}
  local USB_MIN_VERSION=${3:-3}
  local MIN_WRITE_SPEED=${4:-50}
  local MIN_READ_SPEED=${5:-50}

  if [[ -f "$FILENAME" ]]; then
    cat "$FILENAME" |
      jq '.blockdevices[] += { ethmeta: { 
        usb: false, 
        usb3: false, 
        size: false, 
        ssd: false, 
        wspeed: false, 
        rspeed: false 
      }}' |                                                                             # Add ethmeta tracking object
      jq '(.blockdevices[] | select(.tran=="usb") | .ethmeta.usb) |= true' |            # Validate ethmeta.usb
      jq "(.blockdevices[] | select(.size>=$MIN_DISK_SIZE) | .ethmeta.size) |= true" |  # Validate ethmeta.size
      tee "$FILENAME" > /dev/null                                                       # Save to file

    # Validate USB3
    # Unfortunately get_block_devices (lsblk) can't tell us if a device is USB3 or not, so we have to do this manually...
    # TODO: is there a better way? This one is hacky and not always reports correct results
    # for _device in $(cat "$FILENAME" | jq -r '.blockdevices[] .name'); do
    #   # Get BUS:DEVNUM from syspath: /sys/devices/pci0000:00/0000:00:14.0/usb2/2-2/2-2:1.0/host3/target3:0:0/3:0:0:0/block/sdb --> 2-2 --> 2:2
    #   local USB_BUS_DEVNUM=$(readlink -f "/sys/block/$_device" | awk -F/ '{print $7}' | sed 's/-/:/')

    #   if [[ -n "$USB_BUS_DEVNUM" ]]; then
    #     # Get USB version from lsusb's attribute "bcdUSB"
    #     local USB_VERSION=$(lsusb -v -s "$USB_BUS_DEVNUM" 2>/dev/null | grep bcdUSB | awk '{print $2}')
        
    #     if [[ -n "$USB_VERSION" ]]; then
    #       # Strip minor version, we don't care 
    #       local USB_MAJOR_VERSION=$(echo "$USB_VERSION" | awk -F'.' '{print $1}')

    #       if [[ $USB_MAJOR_VERSION -ge "$USB_MIN_VERSION" ]]; then
    #         cat "$FILENAME" |
    #           jq "(.blockdevices[] | select(.name==\"$_device\") | .ethmeta.usb3) |= true" |    # Validate ethmeta.usb3
    #           tee "$FILENAME" > /dev/null                                                       # Save to file
    #       fi
    #     fi
    #   fi
    # done

    # Validate SSD
    # /sys/block/sd*/queue/rotational isn't reporting accurate data, so we use hdparm
    for _device in $(cat "$FILENAME" | jq -r '.blockdevices[] .name'); do
      local NMRR=$(hdparm -I "/dev/$_device" | grep "Nominal Media Rotation Rate" | awk -F':' '{gsub(" ",""); print $2}')
      if [[ "$NMRR" == "SolidStateDevice" ]]; then
        cat "$FILENAME" |
          jq "(.blockdevices[] | select(.name==\"$_device\") | .ethmeta.ssd) |= true" |     # Validate ethmeta.ssd
          tee "$FILENAME" > /dev/null                                                       # Save to file
      fi
    done


    # Validate write & read speeds
    # Mount the device and write/read some data to get the actual speeds
    # However, we only do this for devices that are known to be USB and have enough space for the r/w test
    # USB_CANDIDATES=($(cat "$FILENAME" |
    #   jq -r '[.blockdevices[] | select(.ethmeta.usb==true and .ethmeta.size==true) | .children] | flatten | .[] | select(.size>2) | .path'))
    # 
    # for _device in "${USB_CANDIDATES[@]}"; do
    #   mkdir -p "/mnt/tmp"
    #   mount "$_device" "/mnt/tmp"
    #   dd if=/dev/zero  of=/mnt/tmp/deleteme.dat bs=32M count=64 oflag=direct
    #   dd if=/mnt/tmp/deleteme.dat of=/dev/null bs=32M count=64 iflag=direct
    #   umount "$_device"
    #   rm -rf "/mnt/tmp"
    # done
  fi 
}

# eth_get_onboard_node_candidates
# Returns a list of onboard (not USB) block devices that are capable of being used as an ethereum node
# Parameters:
# - $filename: path to file where blockdevice data is stored. Default: /blockdevices.json
function eth_get_onboard_node_candidates () {
  local FILENAME=${1:-"/blockdevices.json"}

  if [[ -f "$FILENAME" ]]; then
    cat "$FILENAME" |
      jq -r '.blockdevices[] | select(.ethmeta.usb==false and .ethmeta.size==true and .ethmeta.ssd==true) | .path'
  fi
}

# eth_get_usb_node_candidates
# Returns a list of block devices that are capable of being used as an ethereum node
# USB3 reporting is not reliable so we don't filter on that.
# Parameters:
# - $filename: path to file where blockdevice data is stored. Default: /blockdevices.json
function eth_get_usb_node_candidates () {
  local FILENAME=${1:-"/blockdevices.json"}

  if [[ -f "$FILENAME" ]]; then
    cat "$FILENAME" |
      jq -r '.blockdevices[] | select(.ethmeta.usb==true and .ethmeta.size==true and .ethmeta.ssd==true) | .path'
  fi
}

# eth_get_usb_ancient_node_candidates
# Returns a list of block devices that are capable of being used as ancient storage for an ethereum node
# Parameters:
# - $filename: path to file where blockdevice data is stored. Default: /blockdevices.json
# - $node_label: initialized node disk label. Use this to avoid setting same as node. Default: ethnode
function eth_get_usb_ancient_node_candidates () {
  local FILENAME=${1:-"/blockdevices.json"}
  local NODE_LABEL=${2:-"ethnode"}

  if [[ -f "$FILENAME" ]]; then
    cat "$FILENAME" |
      jq -r ".blockdevices[] | select(.children[]?.label!=\"$NODE_LABEL\" and .ethmeta.usb==true and .ethmeta.size==true) | .path" |
      uniq
  fi
}

# eth_find_usb_node
# Checks block devices for an initialized ethereum node, signaled by NODE_LABEL disk label
# Parameters:
# - $filename: path to file where blockdevice data is stored. Default: /blockdevices.json
# - $node_label: initialized node disk label. Default: ethnode
function eth_find_usb_node () {
  local FILENAME=${1:-"/blockdevices.json"}
  local NODE_LABEL=${2:-"ethnode"}

  if [[ -f "$FILENAME" ]]; then
    cat "$FILENAME" |
      jq -r ".blockdevices[] | select(.children[]?.label==\"$NODE_LABEL\") | .children[] .path" |
      uniq
  fi
}

# eth_usb_node_initialize
# Attempts to initialize a usb block device as an ethereum node.
# Parameters:
# - $filename: path to file where blockdevice data is stored. Default: /blockdevices.json
# - $label: disk label to apply to the block device. Default: ethnode
function eth_usb_node_initialize () {
  local FILENAME="$1"
  local NODE_LABEL=${2:-"ethnode"}
  local NODE_MAIN_LABEL="$3"

  if [[ -f "$FILENAME" ]]; then
    echo "Looking for a suitable usb block device to initialize..."

    if [[ -n "$NODE_MAIN_LABEL" ]]; then
      CANDIDATE_DEVICES=($(eth_get_usb_ancient_node_candidates "$FILENAME" "$NODE_MAIN_LABEL"))
    else
      CANDIDATE_DEVICES=($(eth_get_usb_node_candidates "$FILENAME"))
    fi
    echo "Candidate devices: ${CANDIDATE_DEVICES[@]}"

    for DEVICE in "${CANDIDATE_DEVICES[@]}"; do
      echo "Formatting $DEVICE..."
      format_block_device "$DEVICE" "$NODE_LABEL"

      # Validate and check again
      get_block_devices "$FILENAME"
      eth_validate_devices "$FILENAME"
      NODE_DEVICE=$(eth_find_usb_node "$FILENAME" "$NODE_LABEL")
      echo "eth_node_device: $NODE_DEVICE"

      if [[ -n "$NODE_DEVICE" ]]; then
        echo "Device $DEVICE was successfully initialized!"
        break
      else
        echo "Could not initialize $DEVICE. Trying next one..."
      fi
    done
  fi
  
  
}