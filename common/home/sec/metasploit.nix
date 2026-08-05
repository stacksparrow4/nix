{
  config,
  lib,
  pkgs,
  self',
  ...
}:

{
  options = {
    sprrw.sec.metasploit.enable = lib.mkEnableOption "metasploit";
  };

  config = lib.mkIf config.sprrw.sec.metasploit.enable {
    home.packages = [
      pkgs.metasploit
      self'.packages.msfscripts
    ];
  };
}
