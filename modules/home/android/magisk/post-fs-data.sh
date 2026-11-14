#!/system/bin/sh

MAGISKTMP="$1"
SRC="$MAGISKTMP/nix-magisk"
DATABIN=/data/adb/magisk

mkdir -p /data/adb
chmod 700 /data/adb

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

if [ ! -b "$MAGISKTMP/.magisk/device/preinit" ]; then
  mkdir -p "$MAGISKTMP/.magisk/device"
  dev=$(MAKEDEV=1 MAGISKTMP="$MAGISKTMP" "$MAGISKTMP/magisk" --preinit-device)
  log -t nix-magisk "preinit device: ${dev:-<none>}"
fi

exit 0
