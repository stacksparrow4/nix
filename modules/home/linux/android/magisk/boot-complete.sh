#!/system/bin/sh
# Runs as root (u:r:magisk:s0) once sys.boot_completed=1.

MAGISKTMP="$1"
SRC="$MAGISKTMP/nix-magisk"

# Permanently allow `su` for uid 2000 (adb shell). With logging and
# notifications off, magiskd doesn't consult the manager app at all.
if [ -f "$SRC/grant-shell" ]; then
  "$MAGISKTMP/magisk" --sqlite \
    "REPLACE INTO policies (uid,policy,until,logging,notification) VALUES(2000,2,0,0,0)" \
    && log -t nix-magisk "granted root to adb shell (uid 2000)"
fi

# Install the Magisk app if it isn't there yet (magiskd skips this on emulators).
if [ -f "$SRC/Magisk.apk" ]; then
  if [ -z "$(pm path com.topjohnwu.magisk 2>/dev/null)" ]; then
    apk=/data/nix-magisk.apk
    cp "$SRC/Magisk.apk" "$apk"
    chcon u:object_r:magisk_file:s0 "$apk"
    log -t nix-magisk "pm install: $(pm install -g -r "$apk" 2>&1)"
    rm -f "$apk"
  fi
  # Free the tmpfs memory either way.
  rm -f "$SRC/Magisk.apk"
fi

exit 0
