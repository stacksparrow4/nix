{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.sprrw.wordlists;
in
{
  options.sprrw.wordlists = {
    enable = lib.mkEnableOption "wordlists";
  };

  config = lib.mkIf cfg.enable {
    environment.etc."wordlists/seclists".source = pkgs.runCommand "seclists" {} ''
      ln -s ${pkgs.seclists}/share/wordlists/seclists $out
    '';
  };
}
