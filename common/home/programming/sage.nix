{
  config,
  lib,
  pkgs,
  mkSandbox,
  ...
}:

{
  options = {
    sprrw.programming.sage.enable = lib.mkEnableOption "sage";
  };

  config = lib.mkIf config.sprrw.programming.sage.enable {
    home.packages = [
      (mkSandbox {
        name = "sage";
        stdin = true;
        tty = true;
        shareCwd = true;
        prog = "${pkgs.sage}/bin/sage";
      })
    ];
  };
}
