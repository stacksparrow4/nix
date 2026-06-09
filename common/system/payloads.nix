{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.sprrw.payloads;
in
{
  options.sprrw.payloads = {
    enable = lib.mkEnableOption "payloads";
  };

  config = lib.mkIf cfg.enable {
    environment.etc."payloads/seclists".source = pkgs.runCommand "seclists" {} ''
      ln -s ${pkgs.seclists}/share/payloads/seclists $out
    '';

    environment.etc."payloads/linpeas.sh".source = pkgs.fetchurl {
      url = "https://github.com/peass-ng/PEASS-ng/releases/download/20260604-085abf96/linpeas.sh";
      hash = "sha256-9TLMXlNztzaiabcx0WYR1ydzuZHn76gS4yUyCYw2+S0=";
    };
  };
}
