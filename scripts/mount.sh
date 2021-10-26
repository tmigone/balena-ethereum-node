#!/bin/bash
# This script gets executed by a udev rule whenever an external drive is plugged in.
# The following env variables are set by udev, but can be obtained if the script is executed outside of udev context:
# - DEVNAME: Device node name (i.e: /dev/sda1)
# - ID_BUS: Bus type (i.e: usb)
# - ID_FS_TYPE: Device filesystem (i.e: vfat)
# - ID_FS_UUID_ENC: Partition's UUID (i.e: 498E-12EF)
# - ID_FS_LABEL_ENC: Partition's label (i.e: YOURDEVICENAME)

# Figure out if we are being run by udev
if [[ -z $DEVNAME ]]; then
  DEVNAME=$1
  echo "Invalid device name: $DEVNAME" >> /usr/src/mount.log
  exit 1
fi

DEVNAME=${DEVNAME:$1}

# 
function get_usb_drives () {
  USB_DRIVES=()

  local device
  for device in /sys/block/*/device; do
    local sys_path=$(readlink -f "$device")
    local is_usb=$(echo "$sys_path" | grep "usb")
    # if [[ -n $is_usb ]]; then
      USB_DRIVES+=( "$device" )
    # fi
  done

  echo "${USB_DRIVES[@]}"
}

usb_drives=($(get_usb_drives))
for i in "${usb_drives[@]}"; do
  # Test size
  lsblk -O --json
  lsblk  --json --output=name,size,label,path
  # Test USB 3.0
  readlink -f /sys//block/sdb/ | awk -F/ '{print $7}' | sed 's/-/:/'
  echo "$i"
done


lsblk --bytes --json --output=name,size,label,path,tran | 
  jq 'del(.blockdevices[] .children)' |                                             # Remove block children[]
  jq '.blockdevices[] .size /= 1024*1024*1024' |                                    # Convert block size to GB
  jq '.blockdevices[] .size |= floor' |                                             # Round block size to integer
  jq '.blockdevices[] += { ethmeta: { usb: false, usb3: false, size: false }}' |    # Add ethmeta tracking object
  jq '(.blockdevices[] | select(.tran=="usb") | .ethmeta.usb) |= true' |            # Update ethmeta.usb
  jq '(.blockdevices[] | select(.size>=350) | .ethmeta.size) |= true' |             # Update ethmeta.size
  tee blockdevices.json

# Test ethnode initialized (check label)

# blkid
# lsusb
# blockdev

# https://askubuntu.com/questions/162434/how-do-i-find-out-usb-speed-from-a-terminal
# https://askubuntu.com/questions/1103569/how-do-i-change-the-label-reported-by-lsblk
# https://unix.stackexchange.com/questions/116664/map-physical-usb-device-path-to-the-bus-device-number-returned-by-lsusb