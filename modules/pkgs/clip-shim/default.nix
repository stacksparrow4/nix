{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      packages.clip-shim =
        (
          (inputs.crate2nix.lib.tools { inherit pkgs; }).appliedCargoNix {
            name = "sprrw-clip";
            src = ./.;
          }
        ).rootCrate.build;
    };
}
