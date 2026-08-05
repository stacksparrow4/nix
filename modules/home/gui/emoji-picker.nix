{ moduleWithSystem, ... }:

{
  flake.homeModules.gui-emoji-picker = moduleWithSystem (
    { self', ... }:
    { ... }:
    {
      home.packages = [ self'.packages.emoji-picker ];
    }
  );
}
