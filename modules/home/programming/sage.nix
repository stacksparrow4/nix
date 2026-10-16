{ moduleWithSystem, ... }:

{
  flake.homeModules.sage = moduleWithSystem (
    { self', ... }:
    { ... }:
    {
      home.packages = [ self'.packages.sage ];
    }
  );
}
