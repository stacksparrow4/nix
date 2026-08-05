# Aggregate of the headless-safe security aspects. `sec-gui` (binaryninja,
# ghidra, wireshark, caido) is deliberately *not* in here: the vm host wants
# everything below without dragging in a GUI stack.
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
