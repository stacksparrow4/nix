{ moduleWithSystem, ... }:

{
  flake.homeModules.misc = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages = [
        self'.packages.shtris
        self'.packages.zbarimg
        self'.packages.twitch-dl
        self'.packages.yt-dlp
        pkgs.semgrep
        pkgs.gh
        pkgs.ffmpeg
      ];
    }
  );
}
