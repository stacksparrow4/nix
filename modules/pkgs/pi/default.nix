{ inputs, ... }:

{
  perSystem =
    {
      pkgs,
      pkgsLinux,
      pkgsLinuxUnstable,
      config,
      ...
    }:
    {
      packages.pi =
          let
            buildPi =
              pkgs:
              ((inputs.crate2nix.lib.tools { inherit pkgs; }).appliedCargoNix {
                name = "pi";
                src = ./.;
              }).rootCrate.build;
            pi = buildPi pkgs;
            piLinux = buildPi pkgsLinux;
            piLogoSvg = pkgs.fetchurl {
              url = "https://pi.dev/logo-auto.svg";
              hash = "sha256-A9UJwQS5VwBj+iaP0yNe1+DkHa/ZMSTKlMrjcm9Y8Rc=";
            };
            piLogoPng = pkgs.runCommand "pi-logo.png" { nativeBuildInputs = [ pkgs.resvg ]; } ''
              sed 's/#000/#fff/' ${piLogoSvg} > logo-white.svg
              resvg --width 128 --height 128 logo-white.svg $out
            '';
            piWrapper = pkgs.writeShellApplication {
              name = "pi";
              text = ''
                export SPRRW_PI=${pkgsLinuxUnstable.pi-coding-agent}/bin/pi
                export SPRRW_PI_WRAPPER_LINUX=${piLinux}/bin/pi

                export SPRRW_EXTENSIONS=${./extensions}
                export SPRRW_PROMPTS=${./prompts}

                export SPRRW_PI_NOTIFY_ICON=${piLogoPng}

                export PATH="${pkgs.lib.makeBinPath (
                  [ config.packages.box ]
                  ++ pkgs.lib.optional pkgs.stdenv.isLinux pkgs.libnotify
                )}:$PATH"

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
