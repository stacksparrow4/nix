{ pkgs, config, lib, ... }:

let cfg = config.sprrw.font; in {
  options.sprrw.font = {
    mainFont = lib.mkOption {
      type = lib.types.package;
    };

    mainFontName = lib.mkOption {
      type = lib.types.str;
    };
    
    mainFontMonoName = lib.mkOption {
      type = lib.types.str;
    };
  };

  config = {
    sprrw.font = {
      mainFont = pkgs.nerd-fonts.iosevka-term;
      mainFontName = "Iosevka Term Nerd Font";
      mainFontMonoName = "Iosevka Term Nerd Font Mono";
    };

    fonts.packages = [
      cfg.mainFont
    ];
  };
}
