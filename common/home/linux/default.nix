{ lib, config, ... }:

{
  imports = [
    ./i3.nix
    ./rofi.nix
    ./term.nix
  ];

  options = {
    sprrw.linux.enable = lib.mkEnableOption "linux";
  };

  config = lib.mkIf config.sprrw.linux.enable {
    sprrw.linux = {
      rofi.enable = true;
      i3.enable = true;
      term.enable = true;
    };
  };
}
