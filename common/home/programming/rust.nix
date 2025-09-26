{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.programming.rust.enable = lib.mkEnableOption "rust";
  };

  config = lib.mkIf config.sprrw.programming.rust.enable {
    home.packages = with pkgs; [
      cargo
      rustc
      rust-analyzer
      rustfmt
    ];
  };
}
