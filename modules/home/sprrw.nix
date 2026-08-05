{ moduleWithSystem, ... }:

{
  flake.homeModules.sprrw-cli = moduleWithSystem (
    { self', ... }:
    { ... }:
    {
      home.packages = [ self'.packages.sprrw ];
    }
  );
}
