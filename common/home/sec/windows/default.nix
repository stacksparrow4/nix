{
  pkgs,
  lib,
  config,
  self',
  ...
}:

{
  imports = [
    ./bloodhoundpy.nix
    ./gcc.nix
    ./impacket.nix
    ./kerbrute.nix
    ./krbrelayx.nix
    ./netexec.nix
    ./pygpoabuse.nix
    ./rusthound.nix
  ];

  options = {
    sprrw.sec.windows.enable = lib.mkEnableOption "windows";
  };

  config = lib.mkIf config.sprrw.sec.windows.enable {
    sprrw.sec.windows = {
      bloodhoundpy.enable = true;
      gcc.enable = true;
      impacket.enable = true;
      kerbrute.enable = true;
      krbrelayx.enable = true;
      netexec.enable = true;
      pygpoabuse.enable = true;
      rusthound.enable = true;
    };

    home.packages = [
      pkgs.rlwrap
      self'.packages.evil-winrm
      pkgs.samba # rpcclient
      self'.packages.certipy
      self'.packages.bloodyAD
      self'.packages.pwsh
    ];
  };
}
