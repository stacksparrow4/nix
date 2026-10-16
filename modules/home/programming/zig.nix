{
  flake.homeModules.zig =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        zig
        zls
      ];
    };
}
