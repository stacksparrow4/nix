{ pkgs, lib, config, osConfig, ... }:

{
  options = {
    sprrw.term.ghostty = {
      enable = lib.mkEnableOption "ghostty";

      font = {
        family = lib.mkOption {
          type = lib.types.str;
          default = osConfig.sprrw.font.mainFontMonoName;
        };

        size = lib.mkOption {
          type = lib.types.int;
          default = 13;
        };
      };
    };
  };

  config = let
    cfg = config.sprrw.term.ghostty;
  in {
    home.packages = with pkgs; [ viu ];

    programs.ghostty = lib.mkIf cfg.enable {
      enable = true;

      settings = {
        font-family = "${cfg.font.family}";
        font-size = cfg.font.size;
        window-decoration = "none";
        theme = "Carbonfox";
        command = "${pkgs.tmux}/bin/tmux";
      };
    };
  };
}
