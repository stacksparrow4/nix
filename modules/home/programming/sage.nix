{ moduleWithSystem, ... }:

{
  flake.modules.homeManager.sage = moduleWithSystem (
    { self', ... }:
    { ... }:
    {
      home.packages = [ self'.packages.sage ];
    }
  );
}
