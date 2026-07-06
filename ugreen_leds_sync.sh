#!/bin/bash
# Path: /usr/local/bin/ugreen_leds_sync.sh

CLI="/usr/local/bin/ugreen_leds_cli"
BRIGHTNESS="128" # Range: 0 (off) to 255 (max brightness)

declare -A present_disks

# Scan block devices mapped via SCSI/HCTL
while read -r dev hctl; do
    
    # Filter out non-matching HCTL configurations (like USB or NVMe)
    if [[ "$hctl" != *":0:0:0"* ]]; then
        continue
    fi
    
    # Convert HCTL index to physical slot ID (HCTL 0 -> Slot 1, etc.)
    slot=${hctl:0:1}
    disk_id=$((slot + 1))
    led="disk${disk_id}"
    
    # Handle ghost entries during fast hot-unplug transitions
    if [ ! -b "/dev/$dev" ]; then
        continue
    fi
    
    # Register device presence
    present_disks[$led]=1
    
    # 1. Critical Check: SMART Health status
    smart_output=$(smartctl -H /dev/"$dev" 2>/dev/null | grep -i "test result")
    if echo "$smart_output" | grep -qi "FAILED"; then
        $CLI "$led" -color 255 0 0 -on -brightness "$BRIGHTNESS"
        continue
    fi
    
    # 2. Functional Check: ZFS Membership
    if lsblk -f /dev/"$dev" 2>/dev/null | grep -qi "zfs_member"; then
        $CLI "$led" -color 0 255 0 -on -brightness "$BRIGHTNESS"
        continue
    fi
    
    # 3. Default State: Healthy Standalone Disk
    $CLI "$led" -color 255 255 255 -on -brightness "$BRIGHTNESS"

done <<< "$(lsblk -S -d -o NAME,HCTL | tail -n +2)"

# Turn off LEDs for empty bays
for i in {1..4}; do
    led="disk${i}"
    if [ -z "${present_disks[$led]}" ]; then
        $CLI "$led" -off
    fi
done
