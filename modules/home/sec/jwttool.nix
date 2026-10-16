{ moduleWithSystem, ... }:

{
  flake.homeModules.jwttool = moduleWithSystem (
    { self', ... }:
    { ... }:
    {
      home.packages = [ self'.packages.jwt-tool ];
    }
  );
}
