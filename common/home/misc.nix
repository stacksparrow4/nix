{
  pkgs,
  lib,
  config,
  self',
  ...
}:

{
  options.sprrw.misc.enable = lib.mkEnableOption "misc";

  config = lib.mkIf config.sprrw.misc.enable {
    home.packages = [
      self'.packages.vimgolf
      self'.packages.shtris
      self'.packages.zbarimg
      self'.packages.twitch-dl
      self'.packages.yt-dlp
      pkgs.semgrep
      pkgs.gh
      pkgs.ffmpeg
    ];
  };
}
