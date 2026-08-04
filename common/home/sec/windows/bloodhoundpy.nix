{
  lib,
  config,
  mkSandbox,
  self',
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
        prog = "${self'.packages.bloodhound-ce}/bin/bloodhound-ce-python";
      })
    ];
  };
}
