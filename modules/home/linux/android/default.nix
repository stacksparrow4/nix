{ moduleWithSystem, ... }:

{
  flake.homeModules.linux-android = moduleWithSystem (
    { pkgs, ... }:
    { lib, ... }:
    let
      avdName = "Pixel_10";
      device = "pixel";
      platformVersion = "35";

      systemImageType = "google_apis_playstore";
      abiVersion = "x86_64";
      systemImage = "system-images;android-${platformVersion};${systemImageType};${abiVersion}";

      androidComposition = pkgs.androidenv.composeAndroidPackages {
        cmdLineToolsVersion = "latest";
        includeEmulator = true;
        includeSystemImages = true;
        systemImageTypes = [ systemImageType ];
        abiVersions = [ abiVersion ];
        platformVersions = [ platformVersion ];
        includeNDK = false;
      };

      sdk = androidComposition.androidsdk;
      sdkRoot = "${sdk}/libexec/android-sdk";

      # Magisk-rooted copy of the system image's ramdisk, passed to the emulator
      # via `-ramdisk` so the (read-only) SDK stays untouched.
      rootedRamdisk = pkgs.callPackage ./_magisk-ramdisk.nix {
        ramdisk = "${builtins.head androidComposition.system-images}/libexec/android-sdk/system-images/android-${platformVersion}/${systemImageType}/${abiVersion}/ramdisk.img";
        abi = abiVersion;
      };
    in
    {
      home.packages = [ sdk ];

      xdg.desktopEntries.android-emulator = {
        name = "Android Emulator (${avdName})";
        comment = "Start the ${avdName} Android virtual device";
        exec = lib.getExe (
          pkgs.writeShellApplication {
            name = "android-emulator-${avdName}";
            text = ''
              export ANDROID_HOME="${sdkRoot}"
              export ANDROID_SDK_ROOT="${sdkRoot}"
              export QT_QPA_PLATFORM=xcb
              exec "${sdkRoot}/emulator/emulator" -avd "${avdName}" -ramdisk "${rootedRamdisk}" "$@"
            '';
          }
        );
        icon = ./android.svg;
        terminal = false;
        type = "Application";
        categories = [
          "Development"
          "Emulator"
        ];
      };

      systemd.user.services.android-create-avd = {
        Unit = {
          After = [ "default.target" ];
        };

        Service = {
          Type = "oneshot";
          ExecStart =
            let
              createAvd = pkgs.writeShellApplication {
                name = "android-create-avd";
                runtimeInputs = [ sdk ];
                text = ''
                  avdDir="$HOME/.android/avd/${avdName}.avd"
                  if [ -d "$avdDir" ]; then
                    echo "AVD '${avdName}' already exists, nothing to do."
                    exit 0
                  fi

                  echo "Creating AVD '${avdName}' from ${systemImage}..."
                  echo "no" | avdmanager create avd \
                    --name "${avdName}" \
                    --package "${systemImage}" \
                    --device "${device}"
                '';
              };
            in
            lib.getExe createAvd;
        };

        Install.WantedBy = [ "default.target" ];
      };
    }
  );
}
