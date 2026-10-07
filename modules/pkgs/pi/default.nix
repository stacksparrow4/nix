{ inputs, config, ... }:

let
  globalConfig = config;
in
{
  perSystem =
    {
      pkgs,
      pkgsLinux,
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
                src = ./wrapper;
              }).rootCrate.build;
            pi = buildPi pkgs;
            piUpstream = inputs.pi.packages.${pkgsLinux.stdenv.hostPlatform.system}.pi;
            piLinux = buildPi pkgsLinux;
            piLogoPng = pkgs.runCommand "pi-logo.png" { nativeBuildInputs = [ pkgs.resvg ]; } ''
              resvg --width 128 --height 128 ${./pi.svg} $out
            '';
            piWrapper = pkgs.writeShellApplication {
              name = "pi";
              text = ''
                export SPRRW_PI=${piUpstream}/bin/pi
                export SPRRW_PI_VERSION=${piUpstream.version}
                export SPRRW_PI_WRAPPER_LINUX=${piLinux}/bin/pi

                export SPRRW_EXTENSIONS=${./extensions}
                export SPRRW_PROMPTS=${./prompts}
                export SPRRW_THEMES=${./themes}

                export SPRRW_SUBAGENT_BIN=${
                  globalConfig.flake.packages.${pkgsLinux.stdenv.hostPlatform.system}.subagent
                }/bin

                export SPRRW_PI_NOTIFY_ICON=${piLogoPng}
                export SPRRW_PI_NOTIFY_ICON_CACHE_WARM=${./pi-cache-warm.png}

                export PATH="${pkgs.lib.makeBinPath (
                  [ config.packages.box ]
                  ++ pkgs.lib.optional pkgs.stdenv.isLinux pkgs.libnotify
                  ++ pkgs.lib.optional pkgs.stdenv.isDarwin pkgs.terminal-notifier
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
