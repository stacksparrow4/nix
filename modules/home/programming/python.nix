{ moduleWithSystem, ... }:

{
  flake.modules.homeManager.python = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        self'.packages.python
        uv
      ];
    }
  );
}
