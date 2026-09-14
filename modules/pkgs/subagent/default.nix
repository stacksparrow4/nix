{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      packages.subagent =
        ((inputs.crate2nix.lib.tools { inherit pkgs; }).appliedCargoNix {
          name = "subagent";
          src = ./.;
        }).rootCrate.build;
    };
}
