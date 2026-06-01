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
        shareCwd = true;
        prog = "${pkgs.sage}/bin/sage";
      })
    ];
  };
}
