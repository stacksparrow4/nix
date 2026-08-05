{ moduleWithSystem, ... }:

{
  flake.homeModules.sec-windows = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages =
        (with pkgs; [
          rlwrap
          samba # rpcclient
        ])
        ++ (with self'.packages; [
          evil-winrm
          certipy
          bloodyAD
          pwsh
          bloodhound-ce-python
          mingw32-gcc
          mingwW64-gcc
          impacket-sandboxed
          kerbrute
          krbrelayx
          nxc
          pygpoabuse
          rusthound-ce
        ]);
    }
  );
}
