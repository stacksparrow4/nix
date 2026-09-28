#!/system/bin/sh
# Runs as root (u:r:magisk:s0) right before `magisk --post-fs-data`.
#
# Does what the Magisk app's "Additional Setup" (fix_env) would do: populate
# /data/adb/magisk so magiskd finds a complete environment and mounts su/magisk
# into PATH, even on the very first boot.

MAGISKTMP="$1"
SRC="$MAGISKTMP/nix-magisk"
DATABIN=/data/adb/magisk

log -t nix-magisk "post-fs-data: MAGISKTMP=$MAGISKTMP"

mkdir -p /data/adb
chmod 700 /data/adb

# (Re)install whenever the bundled Magisk version differs from what's in /data.
if [ ! -f "$DATABIN/busybox" ] || ! cmp -s "$SRC/util_functions.sh" "$DATABIN/util_functions.sh"; then
  log -t nix-magisk "installing Magisk binaries into $DATABIN"
  rm -rf "$DATABIN"
  mkdir -p "$DATABIN"
  for f in busybox magiskboot magiskinit magiskpolicy init-ld \
           util_functions.sh boot_patch.sh addon.d.sh stub.apk; do
    cp "$SRC/$f" "$DATABIN/$f"
  done
  cp "$MAGISKTMP/magisk" "$DATABIN/magisk"
  chmod 755 "$DATABIN"/*
  chown -R 0:0 "$DATABIN"
fi

# Create $MAGISKTMP/.magisk/device/preinit at runtime (normally done by
# magiskinit from PREINITDEVICE, which can't be computed at build time).
if [ ! -b "$MAGISKTMP/.magisk/device/preinit" ]; then
  mkdir -p "$MAGISKTMP/.magisk/device"
  dev=$(MAKEDEV=1 MAGISKTMP="$MAGISKTMP" "$MAGISKTMP/magisk" --preinit-device)
  log -t nix-magisk "preinit device: ${dev:-<none>}"
fi

exit 0
