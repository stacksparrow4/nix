{
  perSystem =
    {
      pkgs,
      inputs',
      self',
      ...
    }:
    {
      packages.pi =
        let
          pi = (pkgs.callPackage ./wrapper/_Cargo.nix { }).rootCrate.build;
          piUpstream = inputs'.pi.packages.pi.override {
            wl-clipboard = pkgs.emptyDirectory;
            xclip = pkgs.emptyDirectory;
          };
          piLogoPng = pkgs.runCommand "pi-logo.png" { nativeBuildInputs = [ pkgs.resvg ]; } ''
            resvg --width 128 --height 128 ${./pi.svg} $out
          '';
          piWrapper = pkgs.writeShellApplication {
            name = "pi";
            text = ''
              export SPRRW_PI=${piUpstream}/bin/pi
              export SPRRW_PI_VERSION=${piUpstream.version}
              export SPRRW_PI_WRAPPER_LINUX=${pi}/bin/pi

              export SPRRW_EXTENSIONS=${./extensions}
              export SPRRW_PROMPTS=${./prompts}
              export SPRRW_THEMES=${./themes}

              export SPRRW_SUBAGENT_BIN=${self'.packages.subagent}/bin

              export SPRRW_ADDITIONAL_PATH=${self'.packages.bx}/bin''${SPRRW_ADDITIONAL_PATH:+:$SPRRW_ADDITIONAL_PATH}

              export SPRRW_PI_NOTIFY_ICON=${piLogoPng}
              export SPRRW_PI_NOTIFY_ICON_CACHE_WARM=${./pi-cache-warm.png}

              export PATH="${
                pkgs.lib.makeBinPath [
                  self'.packages.box
                  pkgs.libnotify
                ]
              }:$PATH"

              ${pi}/bin/pi "$@"
            '';
          };
        in
        pkgs.runCommand "pi" { nativeBuildInputs = [ pkgs.installShellFiles ]; } ''
          mkdir -p $out/bin
          ln -s ${piWrapper}/bin/pi $out/bin/pi
          installShellCompletion --cmd pi \
            --bash <(${pi}/bin/pi --completions bash) \
            --zsh <(${pi}/bin/pi --completions zsh) \
            --fish <(${pi}/bin/pi --completions fish)
        '';
    };
}
