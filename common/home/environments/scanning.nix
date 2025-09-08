{ pkgs, ... }:

with pkgs; [
  nmap
  rustscan
  nuclei
  sqlmap
  feroxbuster
  ffuf
]
