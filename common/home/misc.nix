{
  pkgs,
  lib,
  config,
  mkSandbox,
  ...
}:

{
  options.sprrw.misc.enable = lib.mkEnableOption "misc";

  config = lib.mkIf config.sprrw.misc.enable {
    home.packages = with pkgs; [
      (pkgs.writeShellScriptBin "vimgolf" ''
        export PATH="${pkgs.vim}/bin:$PATH"
        ${pkgs.vimgolf}/bin/vimgolf "$@"
      '')
      (mkSandbox {
        name = "shtris";
        stdin = true;
        tty = true;
        prog = "${shtris}/bin/shtris";
      })
      (mkSandbox {
        name = "zbarimg";
        stdin = true;
        prog = "${zbar}/bin/zbarimg";
      })
      (mkSandbox {
        name = "twitch-dl";
        shareCwd = true;
        network = true;
        prog = "${twitch-dl}/bin/twitch-dl";
      })
      (mkSandbox {
        name = "yt-dlp";
        shareCwd = true;
        network = true;
        prog = "${yt-dlp}/bin/yt-dlp";
      })
      semgrep
      gh
      ffmpeg
    ];
  };
}
