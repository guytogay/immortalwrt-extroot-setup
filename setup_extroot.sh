(
cat << 'END_OF_SCRIPT' > /root/setup_extroot.sh
#!/bin/sh
set -e

# Change: Threshold lowered to 900MB (943718400 bytes) to fit 1GB disks
SIZE_THRESHOLD=943718400

echo "=== ImmortalWrt Extroot Setup (V4.47 pragmatic++) ==="
echo "Changes: fix get_tran fallback (NAME,TRAN match); optional OHCI/UHCI"

if [ ! -t 0 ]; then
    echo "ERROR: Non-interactive environment detected."
    echo "Run this script in an interactive SSH terminal."
    exit 1
fi

# ---------- helpers ----------
is_mounted() { grep -qs " $1 " /proc/mounts; }

cleanup() {
    is_mounted /tmp/check_reuse && umount /tmp/check_reuse >/dev/null 2>&1 || true
    is_mounted /mnt/new_overlay && umount /mnt/new_overlay >/dev/null 2>&1 || true
    rm -f /tmp/extroot_candidates >/dev/null 2>&1 || true
    rm -rf /tmp/extroot_gen >/dev/null 2>&1 || true
    rmdir /tmp/check_reuse >/dev/null 2>&1 || true
    rmdir /mnt/new_overlay >/dev/null 2>&1 || true
}

trap cleanup EXIT

need_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "ERROR: Missing command: $1"
        [ -n "${2:-}" ] && echo "Hint: $2"
        exit 1
    fi
}

sleep_wait_partition() {
    part="$1"
    timeout="$2"
    while [ ! -b "$part" ]; do
        sleep 1
        timeout=$((timeout - 1))
        if [ "$timeout" -le 0 ]; then
            echo "ERROR: Timeout waiting for partition node: $part"
            exit 1
        fi
    done
}

print_disk_confirm() {
    disk="$1"
    echo "----------------------------------------------------"
    echo "FINAL CONFIRMATION (WILL WIPE THIS DISK): $disk"
    if command -v lsblk >/dev/null 2>&1; then
        echo ""
        lsblk -f "$disk" || true
        echo ""
        lsblk "$disk" || true
    fi
    echo "----------------------------------------------------"
    echo "Type \"yes\" to continue (ANY other input will abort)."
    printf "Input (type \"yes\"): "
    read -r ans
    [ "$ans" = "yes" ] || { echo "Aborted by user."; exit 1; }
}

safe_wipe_signatures() {
    disk="$1"
    if command -v wipefs >/dev/null 2>&1; then
        wipefs -a "$disk" >/dev/null 2>&1 || true
    fi
}

do_partprobe() {
    disk="$1"
    if command -v partprobe >/dev/null 2>&1; then
        partprobe "$disk" >/dev/null 2>&1 || true
    fi
    block hotplug >/dev/null 2>&1 || true
}

fsck_ext4_if_needed() {
    part="$1"
    if command -v e2fsck >/dev/null 2>&1; then
        e2fsck -y -f "$part" >/dev/null 2>&1 || true
    fi
}

mount_ext4_resilient() {
    part="$1"
    mp="$2"
    mkdir -p "$mp"
    is_mounted "$mp" && umount "$mp" >/dev/null 2>&1 || true

    if mount -t ext4 "$part" "$mp" >/dev/null 2>&1; then
        return 0
    fi

    echo "WARN: mount failed, trying e2fsck repair..."
    fsck_ext4_if_needed "$part"
    mount -t ext4 "$part" "$mp"
}

# Fixed + robust TRAN query
get_tran() {
    name="$1"
    tran=""

    tran=$(lsblk -d -n -o TRAN "/dev/$name" 2>/dev/null | head -n1 || true)

    if [ -z "$tran" ]; then
        tran=$(lsblk -d -n -o NAME,TRAN 2>/dev/null | awk -v n="$name" '$1==n {print $2; exit}' || true)
    fi

    [ -z "$tran" ] && tran="unknown"
    echo "$tran"
}

# ---------- step 1 ----------
echo "[1/9] opkg update..."
opkg update

echo "[2/9] install required packages..."
opkg install kmod-fs-ext4 block-mount e2fsprogs kmod-usb-storage

echo "[3/9] optional USB controller drivers (best-effort)..."
opkg install kmod-usb-ohci >/dev/null 2>&1 || true
opkg install kmod-usb-uhci >/dev/null 2>&1 || true

echo "[4/9] install utilities (best-effort)..."
opkg install util-linux >/dev/null 2>&1 || true
opkg install fdisk lsblk blkid >/dev/null 2>&1 || true

need_cmd awk
need_cmd sed
need_cmd tar
need_cmd mount
need_cmd umount
need_cmd fdisk "Install util-linux or fdisk"
need_cmd lsblk "Install util-linux or lsblk"
need_cmd blkid "Install util-linux or blkid"
need_cmd mkfs.ext4 "Install e2fsprogs"

# ---------- step 2: detect root disk ----------
echo "[5/9] detect system disk..."

ROOT_MOUNT=$(awk '$2=="/rom" || $2=="/boot" {print $1; exit}' /proc/mounts)
[ -z "$ROOT_MOUNT" ] && ROOT_MOUNT=$(awk '$2=="/" {print $1; exit}' /proc/mounts)

if [ "$ROOT_MOUNT" = "/dev/root" ]; then
    REAL_DEV=$(lsblk -lno NAME,MOUNTPOINT | awk '$2=="/rom" || $2=="/boot" || $2=="/" {print "/dev/"$1; exit}')
    [ -n "$REAL_DEV" ] && ROOT_MOUNT="$REAL_DEV"
fi

ROOT_DISK_NAME=$(lsblk -no PKNAME "$ROOT_MOUNT" 2>/dev/null | head -n1 | xargs || true)
if [ -z "$ROOT_DISK_NAME" ]; then
    ROOT_DISK_NAME=$(lsblk -no NAME "$ROOT_MOUNT" 2>/dev/null | head -n1 | xargs || true)
fi
[ -n "$ROOT_DISK_NAME" ] || { echo "ERROR: cannot detect system disk."; exit 1; }

ROOT_DISK="/dev/$ROOT_DISK_NAME"
echo "    system disk: $ROOT_DISK"

if ! lsblk -dn -o NAME | grep -q "^${ROOT_DISK_NAME}\$"; then
    echo "ERROR: system disk identity verification failed: $ROOT_DISK"
    exit 1
fi

# ---------- step 3: interactive disk selection ----------
echo "[6/9] select target disk..."

CANDIDATES_FILE="/tmp/extroot_candidates"
rm -f "$CANDIDATES_FILE" >/dev/null 2>&1 || true

lsblk -d -n -o NAME,SIZE,TYPE -b | \
    awk -v root="$ROOT_DISK_NAME" -v limit="$SIZE_THRESHOLD" \
        '$3=="disk" && $1!=root && $2>limit {print $1, $2}' > "$CANDIDATES_FILE"

if [ ! -s "$CANDIDATES_FILE" ]; then
    echo "ERROR: no candidate disks found (non-root and > 900MB)."
    exit 1
fi

echo "----------------------------------------------------"
echo "Choose target disk for extroot:"
echo "----------------------------------------------------"

i=1
while read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    size_bytes=$(echo "$line" | awk '{print $2}')
    tran=$(get_tran "$name")
    size_gb=$(awk "BEGIN {printf \"%.2f\", $size_bytes/1073741824}")
    echo "  [$i] /dev/$name (size: ${size_gb} GiB, tran: ${tran})"
    i=$((i+1))
done < "$CANDIDATES_FILE"

echo "----------------------------------------------------"
printf "Enter number (e.g. \"1\"): "
read -r SELECTION

case "$SELECTION" in
    ''|*[!0-9]*) echo "ERROR: invalid input (must be a number)."; exit 1 ;;
esac

TARGET_DISK_NAME=$(sed -n "${SELECTION}p" "$CANDIDATES_FILE" | awk '{print $1}')
rm -f "$CANDIDATES_FILE" >/dev/null 2>&1 || true

[ -n "$TARGET_DISK_NAME" ] || { echo "ERROR: selection out of range."; exit 1; }

TARGET_DISK="/dev/$TARGET_DISK_NAME"
case "$TARGET_DISK_NAME" in
  nvme*|mmcblk*) TARGET_PART="${TARGET_DISK}p1" ;;
  *)             TARGET_PART="${TARGET_DISK}1" ;;
esac

echo "    target disk: $TARGET_DISK"
echo "    target part: $TARGET_PART"

if awk -v d="$TARGET_DISK_NAME" '
  $1 ~ ("^/dev/" d "([0-9]+|p[0-9]+)?$") && ($2=="/" || $2=="/rom" || $2=="/boot") { found=1 }
  END { exit found?0:1 }
' /proc/mounts; then
  echo "ERROR: target disk contains system mountpoints. abort."
  exit 1
fi

# ---------- step 4: reuse detection ----------
echo "[7/9] reuse detection..."

NEED_INIT=1
if [ -b "$TARGET_PART" ] && blkid "$TARGET_PART" 2>/dev/null | grep -q 'LABEL="overlay"'; then
    NEED_INIT=0
fi

mkdir -p /tmp/check_reuse
if [ -b "$TARGET_PART" ]; then
    if mount -t ext4 -o ro "$TARGET_PART" /tmp/check_reuse >/dev/null 2>&1; then
        :
    elif mount -t ext4 -o rw,noatime "$TARGET_PART" /tmp/check_reuse >/dev/null 2>&1; then
        echo "    note: journal replay happened (rw mount succeeded)."
    else
        NEED_INIT=1
    fi

    if is_mounted /tmp/check_reuse; then
        if [ -d "/tmp/check_reuse/upper/etc/config" ]; then
            echo "    reuse anchor found: upper/etc/config"
            NEED_INIT=0
        else
            NEED_INIT=1
        fi
        umount /tmp/check_reuse >/dev/null 2>&1 || true
    fi
fi

# ---------- step 5 ----------
echo "[8/9] partition/format if needed..."

if [ "$NEED_INIT" -eq 1 ]; then
    print_disk_confirm "$TARGET_DISK"

    safe_wipe_signatures "$TARGET_DISK"
    umount "$TARGET_PART" >/dev/null 2>&1 || true

    printf "g\nn\n\n\n\nw\n" | fdisk "$TARGET_DISK" >/dev/null 2>&1
    do_partprobe "$TARGET_DISK"
    sleep_wait_partition "$TARGET_PART" 30

    mkfs.ext4 -F -L overlay "$TARGET_PART" >/dev/null
else
    echo "    reuse mode: skip repartition/format."
fi

# ---------- step 6 ----------
echo "[9/9] write fstab and sync data..."

UUID=$(blkid -s UUID -o value "$TARGET_PART" 2>/dev/null || true)
[ -n "$UUID" ] || { echo "ERROR: failed to get UUID for $TARGET_PART"; exit 1; }
echo "    uuid: $UUID"

TMP_CONF_DIR="/tmp/extroot_gen"
mkdir -p "$TMP_CONF_DIR/etc/config"

cat << EOF > "$TMP_CONF_DIR/etc/config/fstab"
config global
	option anon_swap '0'
	option anon_mount '1'
	option auto_swap '1'
	option auto_mount '1'
	option delay_root '5'
	option check_fs '0'

config mount
	option target '/overlay'
	option uuid '$UUID'
	option fstype 'ext4'
	option options 'rw,noatime'
	option enabled '1'
EOF

if command -v uci >/dev/null 2>&1; then
    if ! uci -c "$TMP_CONF_DIR/etc/config" show fstab >/dev/null 2>&1; then
        echo "ERROR: generated fstab failed UCI syntax check."
        exit 1
    fi
fi

mv "$TMP_CONF_DIR/etc/config/fstab" /etc/config/fstab
rm -rf "$TMP_CONF_DIR"
sync
echo "    fstab updated."

# ---------- step 7 ----------
mount_ext4_resilient "$TARGET_PART" /mnt/new_overlay

if [ -d "/mnt/new_overlay/upper/etc/config" ]; then
    echo "    reuse mode: existing config found on disk, keep as-is."
else
    echo "    sync mode: clone current /overlay to disk..."
    tar -C /overlay -cpf - . | tar -C /mnt/new_overlay -xpf -
    sync
fi

umount /mnt/new_overlay >/dev/null 2>&1 || true
sync

trap - EXIT
cleanup

echo "Done. Reboot in 3 seconds..."
sleep 3
reboot
END_OF_SCRIPT
chmod +x /root/setup_extroot.sh
/root/setup_extroot.sh
)
