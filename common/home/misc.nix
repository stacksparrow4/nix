{
  pkgs,
  lib,
  config,
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
      (config.sprrw.sandbox.create {
        name = "shtris";
        stdin = true;
        tty = true;
        prog = "${shtris}/bin/shtris";
      })
      (config.sprrw.sandbox.create {
        name = "zbarimg";
        stdin = true;
        prog = "${zbar}/bin/zbarimg";
      })
      (config.sprrw.sandbox.create {
        name = "twitch-dl";
        shareCwd = true;
        prog = "${twitch-dl}/bin/twitch-dl";
      })
      semgrep
      gh
      ffmpeg
    ];
  };
}
