{ moduleWithSystem, ... }:

{
  flake.modules.homeManager.android = moduleWithSystem (
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
                runtimeInputs = [
                  sdk
                  pkgs.gnugrep
                  pkgs.gnused
                ];
                text = ''
                  avdDir="$HOME/.android/avd/${avdName}.avd"
                  if [ -d "$avdDir" ]; then
                    echo "AVD '${avdName}' already exists, skipping creation."
                  else
                    echo "Creating AVD '${avdName}' from ${systemImage}..."
                    echo "no" | avdmanager create avd \
                      --name "${avdName}" \
                      --package "${systemImage}" \
                      --device "${device}"
                  fi

                  config="$avdDir/config.ini"
                  if grep -q '^hw\.keyboard' "$config"; then
                    sed -i 's/^hw\.keyboard *=.*/hw.keyboard=yes/' "$config"
                  else
                    echo 'hw.keyboard=yes' >> "$config"
                  fi
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
