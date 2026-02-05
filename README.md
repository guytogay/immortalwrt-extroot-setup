# ImmortalWrt Extroot Setup Script

A pragmatic, safety-oriented extroot setup script for **ImmortalWrt / OpenWrt-based systems**.

This script migrates `/overlay` to a secondary disk, expanding available storage while keeping system upgrades **safe, predictable, and reversible**.

---

## What This Script Does

- Sets up **extroot** using a secondary data disk  
- Migrates current `/overlay` data to the new disk  
- Uses **UUID-based mount** configuration via `/etc/config/fstab`  
- Preserves existing configuration and installed packages  
- Supports **reuse of an existing extroot disk**  
- Requires **explicit interactive confirmation** before any destructive action  

---

## Prerequisites

### Two Disks Are Required

This script **requires two disks** to function correctly.

### System Disk

- Contains the ImmortalWrt firmware  
- `/rom` is a **squashfs** filesystem (read-only)  
- `/overlay` initially resides on the system disk  
- Usually small (hundreds of MB)  

### Data Disk

- Used as the new `/overlay`  
- Will be formatted as **ext4**  
- All existing data on this disk **may be destroyed**  
- **MUST NOT** be the system disk  

---

## Disk Size Requirement

The data disk must be **larger than 900 MB**.

Default threshold in the script:

```
SIZE_THRESHOLD=943718400
```

If your data disk is smaller than 900 MB, modify this value before running the script.

---

## How to Use

You may use **either** of the following methods.

### Method 1: Copy & Paste Directly in SSH (Recommended)

1. SSH into your ImmortalWrt / OpenWrt system  
2. Copy the **entire script content**  
3. Paste it directly into the SSH terminal  
4. Press Enter to execute  

This method is safe because:

- The script enforces **interactive execution**
- All destructive actions require **explicit confirmation**

---

### Method 2: Save as a Script File

1. Save the script on the router, for example:

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

---

## Interactive Safety Notes

During execution, the script will:

- Ask you to select the target disk by number (for example: `"1"`)  
- Require you to explicitly type `"yes"` before any destructive operation  

Any other input will **abort safely**.

---

## Reuse Detection Logic

If the target partition:

- Has filesystem label `overlay`  
- **AND**
- Contains `upper/etc/config`  

Then the script will treat it as an **existing extroot** and will:

- Skip repartitioning  
- Skip formatting  
- Preserve existing data  

This allows safe reuse of an existing extroot disk.

---

## Verification After Reboot

After the script completes and the system reboots, verify extroot status:

```
mount | grep " /overlay "
df -h /overlay
```

You should see `/overlay` mounted from the data disk with expanded capacity.

---

## System Upgrade Notes (IMPORTANT)

When upgrading ImmortalWrt / OpenWrt firmware:

You may safely use:

- LuCI **Backup and Flash Firmware** (with **Keep settings**)  
- LuCI **Attended Sysupgrade** (with **Keep settings**)  

Configuration, installed packages, and extroot **will be preserved**.

---

### Expected Behavior After Upgrade

On the **first boot after upgrade**:

- Available space may appear smaller  
- Installed packages may seem missing  

This is **NORMAL**.

### What To Do

**Manually reboot the system once more.**

After the second reboot:

- Full extroot space will reappear  
- All installed packages will be restored  

This behavior is caused by overlay / extroot initialization order.

---

## Warnings

- This script can **destroy data** if misused  
- Always double-check the selected disk  
- Never select the system disk as the target  
- Run **only in an interactive SSH session**

---

## License

MIT License

---

## 中文说明（Chinese README）

### ImmortalWrt Extroot 扩容脚本

这是一个**务实、以安全为优先**的 ImmortalWrt / OpenWrt 扩容脚本。

该脚本通过将 `/overlay` 迁移到第二块磁盘，实现存储空间扩展，同时保证系统升级过程**不丢配置、不丢软件、行为可预期**。

---

### 脚本功能

- 使用第二块磁盘配置 extroot  
- 迁移当前 `/overlay` 数据  
- 使用 UUID 挂载，避免设备名变化  
- 支持复用已有 extroot  
- 所有破坏性操作都需要明确交互确认  

---

### 使用前提

#### 必须有两块磁盘

**系统盘**

- 存放 ImmortalWrt 固件  
- `/rom` 为 squashfs（只读）  
- `/overlay` 初始位于系统盘  

**数据盘**

- 作为新的 `/overlay`  
- 会被格式化为 ext4  
- 数据可能被清除  
- 不能是系统盘  

---

### 数据盘容量要求

数据盘容量必须 **大于 900MB**。

脚本默认限制：

```
SIZE_THRESHOLD=943718400
```

---

### 使用方式

#### 方式一（推荐）：SSH 中直接复制整段脚本运行

- SSH 登录系统  
- 复制整段脚本  
- 直接粘贴到终端并执行  

#### 方式二：保存为脚本文件

```
chmod +x /root/setup_extroot.sh
/root/setup_extroot.sh
```

---

### 系统升级注意事项（重要）

升级固件时：

- 勾选 **保留配置**
- extroot、配置、软件都会保留  

**升级后第一次启动**可能看到：

- 空间变小  
- 软件“消失”  

这是正常的。

👉 **手动再重启一次系统，一切都会恢复。**
