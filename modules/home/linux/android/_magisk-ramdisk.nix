# Produces a Magisk-rooted copy of an Android emulator ramdisk.img, doing the
# same thing as rootAVD / Magisk's boot_patch.sh, but offline in the Nix sandbox.
#
# Boot the emulator with `-ramdisk <this derivation>` to use it; the SDK itself
# is left untouched.
{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  python3,

  # The stock ramdisk.img of the system image to root.
  ramdisk,
  # ABI of the system image (which Magisk binaries get embedded).
  abi ? "x86_64",

  magiskVersion ? "30.7",
  magiskHash ? "sha256-4NMtISNTKGD5cSPZJ7G7hsTgjm/YpIv8a1vuCvrp69U=",

  # Written to .backup/.magisk, same defaults rootAVD picks for a modern
  # (system-as-root, encrypted /data) AVD.
  keepVerity ? true,
  keepForceEncrypt ? true,

  # Optional: output of `su -c magisk --preinit-device` on the running AVD.
  # Lets magiskinit mount the preinit partition itself (needed for modules'
  # sepolicy.rule to load early). Without it, the node is created at runtime
  # by magisk/post-fs-data.sh, which is enough for Magisk itself.
  preinitDevice ? null,

  # Bundle the Magisk app and `pm install` it on boot if missing.
  installApp ? true,
  # Permanently allow `su` for `adb shell` (uid 2000), no prompt needed.
  grantShellRoot ? true,
}:

let
  magiskApk = fetchurl {
    url = "https://github.com/topjohnwu/Magisk/releases/download/v${magiskVersion}/Magisk-v${magiskVersion}.apk";
    hash = magiskHash;
  };

  # magiskboot is a static binary, so the build-platform flavour runs fine on
  # a regular Linux host.
  buildAbi =
    {
      x86_64 = "x86_64";
      aarch64 = "arm64-v8a";
    }
    .${stdenvNoCC.buildPlatform.parsed.cpu.name}
      or (throw "magisk-ramdisk: unsupported build platform ${stdenvNoCC.buildPlatform.system}");

  bool = b: if b then "true" else "false";
in
stdenvNoCC.mkDerivation {
  pname = "magisk-ramdisk";
  version = magiskVersion;

  nativeBuildInputs = [
    unzip
    python3
  ];

  dontUnpack = true;
  dontConfigure = true;
  dontFixup = true;

  passthru.magiskApk = magiskApk;

  buildPhase = ''
    runHook preBuild

    unzip -q ${magiskApk} 'lib/*' 'assets/stub.apk'

    install -m755 lib/${buildAbi}/libmagiskboot.so magiskboot
    cp lib/${abi}/libmagiskinit.so magiskinit
    cp lib/${abi}/libmagisk.so     magisk
    cp lib/${abi}/libinit-ld.so    init-ld
    cp assets/stub.apk             stub.apk

    # Files for bootstrapping /data/adb/magisk at boot (see magisk/*.sh):
    # the same set the Magisk app extracts before running fix_env.
    unzip -q ${magiskApk} 'assets/util_functions.sh' 'assets/boot_patch.sh' 'assets/addon.d.sh'
    mkdir nix-magisk
    cp lib/${abi}/libbusybox.so      nix-magisk/busybox
    cp lib/${abi}/libmagiskboot.so   nix-magisk/magiskboot
    cp lib/${abi}/libmagiskinit.so   nix-magisk/magiskinit
    cp lib/${abi}/libmagiskpolicy.so nix-magisk/magiskpolicy
    cp lib/${abi}/libinit-ld.so      nix-magisk/init-ld
    cp assets/{util_functions.sh,boot_patch.sh,addon.d.sh,stub.apk} nix-magisk/
    cp ${./magisk/post-fs-data.sh}  nix-magisk/post-fs-data.sh
    cp ${./magisk/boot-complete.sh} nix-magisk/boot-complete.sh
    ${lib.optionalString installApp "cp ${magiskApk} nix-magisk/Magisk.apk"}
    ${lib.optionalString grantShellRoot "touch nix-magisk/grant-shell"}

    # --- Decompress --------------------------------------------------------
    ./magiskboot decompress ${ramdisk} full.cpio 2>&1 | tee decompress.log
    method=$(sed -n 's/^Detected format: *//p' decompress.log)
    [ -n "$method" ] || { echo "Could not detect ramdisk compression" >&2; exit 1; }
    echo "Ramdisk compression: $method"

    # --- Split concatenated cpio archives ----------------------------------
    # Emulator ramdisks (API 30+) are several cpio archives glued together;
    # the first one holds /init and the device nodes, the rest just add
    # lib/modules etc. magiskboot only understands a single archive, so patch
    # the first one and append the rest verbatim (this keeps ownership and
    # device nodes intact, which a sandboxed extract/repack would not).
    python3 - <<'EOF'
    # Walk the newc headers properly (searching for the "TRAILER!!!" string
    # is not safe: e.g. busybox/init binaries can contain it).
    data = open("full.cpio", "rb").read()
    align = lambda n: (n + 3) & ~3
    off = 0
    while True:
        if data[off:off + 6] not in (b"070701", b"070702"):
            raise SystemExit(f"bad cpio magic at offset {off}")
        namesize = int(data[off + 94:off + 102], 16)
        filesize = int(data[off + 54:off + 62], 16)
        name = data[off + 110:off + 110 + namesize - 1]
        off = align(align(off + 110 + namesize) + filesize)
        if name == b"TRAILER!!!":
            break
    nxt = off
    while nxt < len(data) and data[nxt] == 0:
        nxt += 1
    if nxt < len(data) and data[nxt:nxt + 6] not in (b"070701", b"070702"):
        raise SystemExit("unexpected data after first cpio archive")
    open("ramdisk.cpio", "wb").write(data[:nxt])
    open("rest.cpio", "wb").write(data[nxt:])
    print(f"first archive: {nxt} bytes, remaining archives: {len(data) - nxt} bytes")
    EOF

    # --- Sanity check: must be a stock ramdisk ------------------------------
    status=0
    ./magiskboot cpio ramdisk.cpio test || status=$?
    if [ $((status & 3)) -ne 0 ]; then
      echo "ramdisk is already patched or modified (status=$status)" >&2
      exit 1
    fi
    sha1=$(./magiskboot sha1 ramdisk.cpio)
    cp ramdisk.cpio ramdisk.cpio.orig

    # --- Patch (mirrors assets/boot_patch.sh from the Magisk APK) -----------
    ./magiskboot compress=xz magisk   magisk.xz
    ./magiskboot compress=xz stub.apk stub.xz
    ./magiskboot compress=xz init-ld  init-ld.xz

    # PREINITDEVICE is omitted: it is computed by running `magisk
    # --preinit-device` on the device, which is impossible at build time.
    cat > config <<EOF
    KEEPVERITY=${bool keepVerity}
    KEEPFORCEENCRYPT=${bool keepForceEncrypt}
    RECOVERYMODE=false
    VENDORBOOT=false
    SHA1=$sha1
    ${lib.optionalString (preinitDevice != null) "PREINITDEVICE=${preinitDevice}"}
    EOF

    export KEEPVERITY=${bool keepVerity}
    export KEEPFORCEENCRYPT=${bool keepForceEncrypt}

    ./magiskboot cpio ramdisk.cpio \
      "add 0750 init magiskinit" \
      "mkdir 0750 overlay.d" \
      "mkdir 0750 overlay.d/sbin" \
      "add 0644 overlay.d/sbin/magisk.xz magisk.xz" \
      "add 0644 overlay.d/sbin/stub.xz stub.xz" \
      "add 0644 overlay.d/sbin/init-ld.xz init-ld.xz" \
      "patch" \
      "backup ramdisk.cpio.orig" \
      "mkdir 000 .backup" \
      "add 000 .backup/.magisk config"

    # Extra overlay.d content. Added *after* `backup` so it isn't recorded as
    # part of Magisk's own patch (it's ours, not Magisk's).
    extra=("add 0644 overlay.d/nix-magisk.rc ${./magisk/nix-magisk.rc}"
           "mkdir 0755 overlay.d/sbin/nix-magisk")
    for f in nix-magisk/*; do
      extra+=("add 0755 overlay.d/sbin/$f $f")
    done
    ./magiskboot cpio ramdisk.cpio "''${extra[@]}"

    # --- Reassemble & recompress -------------------------------------------
    # Pad to a 512-byte boundary so the next archive starts aligned.
    python3 -c '
    import os
    size = os.path.getsize("ramdisk.cpio")
    with open("ramdisk.cpio", "ab") as f:
        f.write(b"\0" * (-size % 512))
    '
    cat ramdisk.cpio rest.cpio > patched.cpio
    ./magiskboot compress="$method" patched.cpio ramdisk.img

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 ramdisk.img $out
    runHook postInstall
  '';

  meta = {
    description = "Magisk-patched Android emulator ramdisk";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
