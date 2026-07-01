{
  pkgs,
  lib,
  config,
  mkSandbox,
  ...
}:

{
  options = {
    sprrw.sec.windows.bloodhoundpy.enable = lib.mkEnableOption "bloodhoundpy";
  };

  config = lib.mkIf config.sprrw.sec.windows.bloodhoundpy.enable {
    home.packages = [
      (mkSandbox {
        name = "bloodhound-ce";
        shareCwd = true;
        network = true;
        prog = "${import ../../../../pkgs/bloodhound-ce { inherit pkgs; }}/bin/bloodhound-ce-python";
      })
    ];
  };
}
