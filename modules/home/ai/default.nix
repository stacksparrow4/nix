{ moduleWithSystem, ... }:

{
  flake.homeModules.ai = {
    imports = [
      (moduleWithSystem (
        { self', ... }:
        { ... }:
        {
          home.packages = [ self'.packages.bx ];
        }
      ))
    ];
  };
}
