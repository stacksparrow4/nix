{ pkgs, lib, config, ... }@inputs:

{
  imports = [
    ./bloodhoundpy.nix
    ./gcc.nix
    ./impacket.nix
    ./kerbrute.nix
    ./krbrelayx.nix
    ./netexec.nix
    ./pygpoabuse.nix
    ./responder-docker.nix
    ./rusthound.nix
  ];

  options = {
    sprrw.sec.windows.enable = lib.mkEnableOption "windows";
  };

  config = let
    pkgs = import ./pinned-pkgs.nix { system = inputs.pkgs.stdenv.hostPlatform.system; };
  in lib.mkIf config.sprrw.sec.windows.enable {
    sprrw.sec.windows = {
      bloodhoundpy.enable = true;
      gcc.enable = true;
      impacket.enable = true;
      kerbrute.enable = true;
      krbrelayx.enable = true;
      netexec.enable = true;
      pygpoabuse.enable = true;
      responder-docker.enable = true;
      rusthound.enable = true;
    };

    home.packages = with pkgs; [
      rlwrap
      evil-winrm
      samba # rpcclient
      certipy
      python312Packages.bloodyad
    ];
  };
}
