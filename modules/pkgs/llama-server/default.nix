{
  perSystem =
    { pkgs, ... }:
    {
      packages.llama-server = (import ./_Cargo.nix { inherit pkgs; }).rootCrate.build;
    };
}
