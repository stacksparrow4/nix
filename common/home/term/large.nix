{ pkgs, lib, config, ... }:

{
  options.sprrw.term.large.enable = lib.mkEnableOption "large";

  config = lib.mkIf config.sprrw.term.large.enable {
    home.packages = with pkgs; [
      ffmpeg
    ];
  };
}
