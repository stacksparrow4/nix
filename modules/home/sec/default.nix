{ config, ... }:

{
  flake.homeModules.sec = {
    imports = with config.flake.homeModules; [
      cracking
      forensics
      jwttool
      metasploit
      mobile
      pwn
      pwnproxy
      reversing
      scanning
      snmp
      web
      windows
    ];
  };
}
