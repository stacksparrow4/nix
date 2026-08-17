{
  perSystem =
    { pkgs, ... }:
    {
      packages.sprrw = (import ./_Cargo.nix { inherit pkgs; }).rootCrate.build;
    };
}
