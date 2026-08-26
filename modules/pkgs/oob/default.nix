{ config, ... }:

let
  globalConfig = config;
in
{
  perSystem =
    {
      pkgs,
      pkgsLinux,
      config,
      mkSandbox,
      ...
    }:
    {
      packages =
        let
          mkOob =
            { pkgs, interactsh }:
            let
              oobBin = (import ./_Cargo.nix { inherit pkgs; }).rootCrate.build;
            in
            pkgs.runCommand "oob-unboxed"
              {
                nativeBuildInputs = with pkgs; [ makeWrapper ];
                meta.mainProgram = "oob";
              }
              ''
                mkdir -p $out/bin
                makeWrapper ${oobBin}/bin/oob $out/bin/oob \
                  --prefix PATH : ${pkgs.lib.makeBinPath [ interactsh ]}
              '';
        in
        {
          oob-unboxed = mkOob {
            inherit pkgs;
            interactsh = config.packages.interactsh-unboxed;
          };

          oob =
            let
              oobWrapped = mkOob {
                pkgs = pkgsLinux;
                interactsh = globalConfig.flake.packages.${pkgsLinux.stdenv.hostPlatform.system}.interactsh-unboxed;
              };
            in
            mkSandbox {
              name = "oob";
              prog = "${oobWrapped}/bin/oob";
              sharedPaths = [
                {
                  hostPath = "$HOME/.config/interactsh-client/config.yaml";
                  boxPath = "~/.config/interactsh-client/config.yaml";
                  ro = true;
                  type = "file";
                }
              ];
              network = true;
            };
        };
    };
}
