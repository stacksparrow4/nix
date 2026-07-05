{
  config,
  lib,
  pkgs,
  ...
}:

{
  options = {
    sprrw.programming.zig.enable = lib.mkEnableOption "zig";
  };

  config = lib.mkIf config.sprrw.programming.zig.enable {
    home = {
      packages = with pkgs; [
        zig
        zls
      ];
    };
  };
}
