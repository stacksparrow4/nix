{ ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      packages.subagent =
        (pkgs.callPackage ./_Cargo.nix { }).rootCrate.build;
    };
}
