{ config, ... }:

{
  flake.homeModules.sec = {
    imports = with config.flake.homeModules; [
      sec-cracking
      sec-forensics
      sec-jwttool
      sec-metasploit
      sec-mobile
      sec-pwn
      sec-pwnproxy
      sec-reversing
      sec-scanning
      sec-snmp
      sec-web
      sec-windows
    ];
  };
}
