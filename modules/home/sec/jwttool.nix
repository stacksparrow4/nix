{ moduleWithSystem, ... }:

{
  flake.homeModules.sec-jwttool = moduleWithSystem (
    { self', ... }:
    { ... }:
    {
      home.packages = [ self'.packages.jwt-tool ];
    }
  );
}
