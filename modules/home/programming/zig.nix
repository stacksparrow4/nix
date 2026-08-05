{
  flake.homeModules.programming-zig =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        zig
        zls
      ];
    };
}
