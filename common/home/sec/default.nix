{ lib, config, ... }:

{
  imports = [
    ./burp.nix
    ./cracking.nix
    ./forensics.nix
    ./metasploit.nix
    ./mitmproxy.nix
    ./pwn.nix
    ./scanning.nix
    ./snmp.nix
    ./windows
  ];

  options = {
    sprrw.sec.enable = lib.mkEnableOption "sec";
  };

  config = lib.mkIf config.sprrw.sec.enable {
    sprrw.sec = {
      burp.enable = true;
      cracking.enable = true;
      forensics.enable = true;
      metasploit.enable = true;
      mitmproxy.enable = true;
      pwn.enable = true;
      scanning.enable = true;
      snmp.enable = true;
      windows.enable = true;
    };
  };
}
