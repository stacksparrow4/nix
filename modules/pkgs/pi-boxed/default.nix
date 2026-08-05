{ inputs, ... }:

{
  perSystem =
    { pkgs, config, lib, ... }:
    let
      craneLib = inputs.crane.mkLib pkgs;

      commonArgs = {
        src = craneLib.cleanCargoSource ./.;
        strictDeps = true;
      };

      cargoArtifacts = craneLib.buildDepsOnly commonArgs;

      pi-boxed = craneLib.buildPackage (
        commonArgs
        // {
          inherit cargoArtifacts;
        }
      );
    in
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        pi-boxed = pkgs.writeShellApplication {
          name = "pi";
          text = ''
            ${pi-boxed}/bin/pi ${config.packages.pi}/bin/pi "$@"
          '';
        };
      };
    };
}
