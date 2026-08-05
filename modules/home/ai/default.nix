{ config, moduleWithSystem, ... }:

{
  # The `bx` wrapper plus the always-wanted AI plumbing. `ai-llama` and `ai-pi`
  # carry per-host data (models, exec model) so hosts import them explicitly.
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
