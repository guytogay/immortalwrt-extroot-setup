### ImmortalWrt / OpenWrt Overlay 扩容脚本

这是一个面向 **ImmortalWrt / OpenWrt 系列系统**的、**务实且以安全为优先**的 extroot 自动化脚本。

脚本会把系统的 `/overlay` 迁移到第二块磁盘，从而扩展可用存储空间，同时尽量保证系统升级过程 **安全、可预期、可回退**。

---

### 脚本能做什么

- 为系统配置 **extroot**（把 `/overlay` 放到第二块磁盘上）
- 将当前 `/overlay` 数据迁移到新磁盘
- 通过写入 `/etc/config/fstab` 使用 **UUID 挂载**（避免设备名变化导致挂载错盘）
- 支持检测并 **复用已有 extroot 数据盘**（不强制重置）
- 在执行任何可能导致数据损毁的操作前，要求 **明确的交互确认**
- 运行方式限制为 **交互式终端**（避免被管道/重定向误触发）

---

### 前置条件（必读）

#### 必须有两块盘

此脚本必须在“至少两块盘”的前提下运行：

- 一块是 **系统盘**
- 一块是 **数据盘（extroot 目标盘）**

---

### 系统盘（System Disk）

系统盘用于存放 ImmortalWrt 固件与基础系统：

- `/rom` 是 **squashfs**（只读）文件系统
- `/overlay` 初始位于系统盘（或其对应的可写分区/覆盖层）
- 系统盘通常较小（几百 MB 量级）

---

### 数据盘（Data Disk / Extroot Target）

数据盘用于承载新的 `/overlay`：

- 会被格式化为 **ext4**
- 可能会执行分区/格式化等破坏性动作
- **盘内原有数据可能被清空（数据将不可恢复）**
- **绝对不能选择系统盘作为目标盘**

---

### 数据盘容量要求

数据盘容量必须 **大于 900MB**。

脚本中默认阈值为：

```sh
SIZE_THRESHOLD=943718400
```

如果你的数据盘小于 900MB，请在运行前自行调整该阈值（例如降低限制），否则脚本会认为没有可用候选盘。

---

## 使用方法

你可以使用以下两种方式之一运行脚本。

---

### 方法 1：SSH 中直接复制粘贴整段脚本运行（推荐）

1. SSH 登录到 ImmortalWrt / OpenWrt 系统
2. 复制脚本完整内容
3. 直接粘贴到 SSH 终端
4. 回车执行

推荐原因：

- 脚本强制要求 **交互式环境**
- 所有破坏性操作都需要你明确确认
- 不容易出现“误触发/半截脚本/脚本文件编码问题”等情况

---

### 方法 2：保存为脚本文件后运行

1. 将脚本保存到路由器上，例如：

```sh
/root/setup_extroot.sh
```

2. 赋予可执行权限：

```sh
chmod +x /root/setup_extroot.sh
```

3. 确保在**交互式 SSH 会话**里运行：

```sh
/root/setup_extroot.sh
```

---

## 交互与安全机制说明

运行过程中脚本会提示你输入两类内容：

1. **选择目标盘编号**（例如输入 `"1"`）
2. 在确认会清空磁盘时，必须手动输入 **`"yes"`** 才会继续

任何其它输入都会 **安全中止**，避免误操作。

---

## Reuse（复用）检测逻辑说明

脚本会判断目标分区是否已有 extroot 数据，以决定是否需要重新分区/格式化。

当目标分区满足以下条件时，会被视为“可复用的 extroot”：

- 分区存在 `LABEL="overlay"`  
并且/或者
- 能挂载后发现存在路径：`upper/etc/config`

一旦识别为复用模式，脚本会：

- **跳过**重新分区
- **跳过**重新格式化
- **保留**盘内已有内容（包括配置与已安装包）

这可以用于“你曾经做过 extroot，现在重新跑脚本时希望继续沿用原盘”的场景。

---

## 重启后如何验证是否成功

脚本执行完毕会重启系统。系统起来后，请执行：

```sh
mount | grep " /overlay "
df -h /overlay
```

你应当看到：

- `/overlay` 来自数据盘分区（ext4）
- `/overlay` 的容量明显增大（取决于你的数据盘大小）

---

## 系统升级注意事项（非常重要）

当你升级 ImmortalWrt / OpenWrt 固件时，只要勾选 **保留配置（Keep settings）**，无论使用以下哪种方式，extroot 通常都能保留：

- LuCI：**备份与升级** → **刷写新固件**（勾选保留配置）
- LuCI：**值守式系统更新（Attended Sysupgrade）**（勾选保留配置）

在你的实际测试中：

- 配置不会丢
- 软件空间不会回退缩小
- 已安装的软件也不会真正丢失

---

### 升级后“第一次进入系统”可能出现的现象

你已经观察到一个**需要重点提醒**的现象：

- 固件升级完成后，**第一次进入系统**时看起来会：
  - 空间变小
  - 软件像是丢失了

这通常是 overlay/extroot 初始化时序造成的“暂时状态”。

---

### 正确处理方式

**只需要手动再重启一次系统。**

第二次重启后：

- 空间会恢复到 extroot 的正确容量
- 已安装的软件会全部回来

这点建议写在 README 里加粗提醒，因为容易让人误判为“升级把 extroot 弄坏了”。

---

## 风险提示（Warnings）

- 该脚本可能会清空目标盘数据（数据不可恢复）
- 请选择目标盘时务必再次确认
- **不要选择系统盘**
- 请务必在 **交互式 SSH 终端**执行脚本，避免重定向/管道导致的误操作

---

## 许可证（License）

MIT License

---

# ImmortalWrt / OpenWrt Overlay Expander Script

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
