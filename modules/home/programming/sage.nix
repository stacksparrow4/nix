{ moduleWithSystem, ... }:

{
  flake.homeModules.programming-sage = moduleWithSystem (
    { self', ... }:
    { ... }:
    {
      home.packages = [ self'.packages.sage ];
    }
  );
}
