# ImmortalWrt Extroot Setup Script (V4.47 pragmatic++)

A defensive, interactive script to setup extroot (/overlay) on ImmortalWrt/OpenWrt.

## WARNING
This script can WIPE a target disk. Read prompts carefully.

## Usage
1. Copy script to router:
   - Upload `setup_extroot.sh` to `/root/`
2. Run in an interactive SSH terminal:
   sh /root/setup_extroot.sh

## Verify after reboot
mount | grep " /overlay "
df -h /overlay
