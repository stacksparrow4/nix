{ config, moduleWithSystem, ... }:

{
  flake.modules.homeManager.sec = {
    imports = with config.flake.modules.homeManager; [
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
