{ config, lib, pkgs, ... }:

{
  options = {
    sprrw.sec.metasploit.enable = lib.mkEnableOption "metasploit";
  };

  config = lib.mkIf config.sprrw.sec.metasploit.enable {
    home.packages = with pkgs; [
      metasploit
    ];
  };
}
