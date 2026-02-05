# ImmortalWrt Extroot Setup Script (V4.47 pragmatic++)

A defensive, interactive script to setup **extroot (/overlay)** on ImmortalWrt / OpenWrt.

This script migrates the writable system overlay to a separate data disk, greatly expanding available storage for packages and configuration.

---

## ⚠️ Important Prerequisites

This script **REQUIRES at least two disks**:

### 1. System Disk
- Contains ImmortalWrt firmware
- Uses **squashfs + overlayfs**
- `/rom` is squashfs (read-only)
- `/overlay` is ext4 (writable layer)

> The system disk itself is **NOT ext4 rootfs** and does not need to be large.

### 2. Data Disk (Target for extroot)
- A **separate physical or virtual disk**
- Will be **fully wiped and repartitioned**
- Used to host `/overlay`

⚠️ **All existing data on the data disk will be destroyed.**

---

## 📏 Disk Size Requirement

By default, the script only lists disks **larger than 900 MB**:

```sh
SIZE_THRESHOLD=943718400
