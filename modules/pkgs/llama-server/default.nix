{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      packages.llama-server =
        ((inputs.crate2nix.lib.tools { inherit pkgs; }).appliedCargoNix {
          name = "llama-server";
          src = ./.;
        }).rootCrate.build;
    };
}
