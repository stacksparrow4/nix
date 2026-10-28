{ config, moduleWithSystem, ... }:

{
  flake.homeModules.sec = {
    imports = with config.flake.homeModules; [
      cracking
      forensics
      metasploit
      mobile
      pwn
      pwnproxy
      reversing
      scanning
      snmp
      web
      windows

      (moduleWithSystem (
        { self', ... }:
        { ... }:
        {
          home.packages = [ self'.packages.jwt-tool ];
        }
      ))
    ];
  };
}
