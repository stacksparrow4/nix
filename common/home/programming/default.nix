{ config, lib, ... }:

{
  imports = [
    ./c.nix
    ./databases.nix
    ./git.nix
    ./go.nix
    ./kubernetes.nix
    ./lua.nix
    ./node.nix
    ./php.nix
    ./rust.nix
    ./sage.nix
    ./typst.nix
    ./xml.nix
    ./java.nix
  ];

  options = {
    sprrw.programming.enable = lib.mkEnableOption "programming";
  };

  config = lib.mkIf config.sprrw.programming.enable {
    sprrw.programming = {
      c.enable = true;
      databases.enable = true;
      git.enable = true;
      go.enable = true;
      kubernetes.enable = true;
      lua.enable = true;
      node.enable = true;
      php.enable = true;
      rust.enable = true;
      sage.enable = true;
      typst.enable = true;
      xml.enable = true;
      java.enable = true;
    };
  };
}
