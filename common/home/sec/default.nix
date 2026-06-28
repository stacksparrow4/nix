{ lib, config, ... }:

{
  imports = [
    ./gui.nix
    ./caido.nix
    ./cracking.nix
    ./forensics.nix
    ./metasploit.nix
    ./web.nix
    ./pwnproxy
    ./pwn.nix
    ./scanning.nix
    ./snmp.nix
    ./reversing.nix
    ./mobile.nix
    ./windows
    ./jwttool.nix
  ];

  options = {
    sprrw.sec.enable = lib.mkEnableOption "sec";
  };

  config = lib.mkIf config.sprrw.sec.enable {
    sprrw.sec = {
      gui.enable = true;
      caido.enable = true;
      cracking.enable = true;
      forensics.enable = true;
      metasploit.enable = true;
      web.enable = true;
      pwnproxy.enable = true;
      pwn.enable = true;
      scanning.enable = true;
      snmp.enable = true;
      windows.enable = true;
      reversing.enable = true;
      mobile.enable = true;
      jwttool.enable = true;
    };
  };
}
