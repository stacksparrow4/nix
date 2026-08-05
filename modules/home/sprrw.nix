{ moduleWithSystem, ... }:

{
  # The `sprrw` CLI itself (modules/pkgs/sprrw).
  flake.homeModules.sprrw-cli = moduleWithSystem (
    { self', ... }:
    { ... }:
    {
      home.packages = [ self'.packages.sprrw ];
    }
  );
}
