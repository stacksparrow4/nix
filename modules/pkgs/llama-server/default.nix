{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      craneLib = inputs.crane.mkLib pkgs;

      commonArgs = {
        src = craneLib.cleanCargoSource ./.;
        strictDeps = true;
      };

      cargoArtifacts = craneLib.buildDepsOnly commonArgs;
    in
    {
      packages.llama-server = craneLib.buildPackage (
        commonArgs
        // {
          inherit cargoArtifacts;
        }
      );
    };
}
