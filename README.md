# ImmortalWrt Extroot Setup Script

A pragmatic, safety-oriented extroot setup script for ImmortalWrt / OpenWrt-based systems.

This script migrates `/overlay` to a secondary disk, expanding available storage while keeping system upgrades safe.

---

## What This Script Does

- Sets up extroot using a secondary disk
- Migrates current `/overlay` data
- Uses UUID-based mount in `/etc/config/fstab`
- Preserves configuration and installed packages
- Supports reuse of existing extroot
- Requires explicit interactive confirmation for destructive actions

---

## Prerequisites

### Two Disks Are Required

#### System Disk

- Contains ImmortalWrt firmware
- `/rom` is squashfs (read-only)
- `/overlay` initially resides here

#### Data Disk

- Used as the new `/overlay`
- All existing data on this disk **may be destroyed**
- Must **NOT** be the system disk

---

## Disk Size Requirement

The data disk must be larger than **900 MB**.

The default threshold in the script is:

```
SIZE_THRESHOLD=943718400
```

If your data disk is smaller, modify this value before running the script.

---

## How to Use

1. Upload the script to your router, for example:

```
/root/setup_extroot.sh
```

2. Make it executable:

```
chmod +x /root/setup_extroot.sh
```

3. Run it in an **interactive SSH session**:

```
/root/setup_extroot.sh
```

Follow the on-screen prompts carefully.

---

## Reuse Detection Logic

If the selected target partition:

- Has filesystem label `overlay`
- Contains directory `upper/etc/config`

Then the script treats it as an existing extroot and will:

- Skip repartitioning
- Skip formatting
- Preserve existing data

---

## Verification After Reboot

After reboot, verify extroot status:

```
mount | grep " /overlay "
df -h /overlay
```

You should see `/overlay` mounted from the data disk with expanded capacity.

---

## System Upgrade Notes (Important)

When upgrading firmware **with “Keep configuration” enabled** (either via LuCI or attended upgrade):

### Expected Behavior

- On the **first boot after upgrade**:
  - Available space may appear smaller
  - Installed packages may seem missing

### What To Do

**Manually reboot the system once more.**

After the second reboot:

- Overlay space is restored
- Installed packages reappear
- Configuration remains intact

This behavior is normal for extroot-based systems.

---

## Safety Notes

- Never select a disk mounted as `/`, `/rom`, or `/overlay`
- Never wipe a live overlay disk
- The script refuses to run in non-interactive environments

---

## License

MIT License

---
