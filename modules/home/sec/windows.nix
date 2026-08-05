{ moduleWithSystem, ... }:

{
  # One aspect for the whole Windows/AD toolkit: the eight former
  # `sec-windows-*` files were each a single-package list and were always
  # enabled together. The *packages* stay separate (modules/pkgs), only the
  # aspect is merged.
  flake.homeModules.sec-windows = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.rlwrap
        self'.packages.evil-winrm
        pkgs.samba # rpcclient
        self'.packages.certipy
        self'.packages.bloodyAD
        self'.packages.pwsh

        self'.packages.bloodhound-ce-python
        self'.packages.mingw32-gcc
        self'.packages.mingwW64-gcc
        self'.packages.impacket-sandboxed
        self'.packages.kerbrute
        self'.packages.krbrelayx
        self'.packages.nxc
        self'.packages.pygpoabuse
        self'.packages.rusthound-ce
      ];
    }
  );
}
