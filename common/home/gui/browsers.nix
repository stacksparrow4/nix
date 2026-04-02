{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.sprrw.gui.browsers = {
    enable = lib.mkEnableOption "browsers";
  };

  # Extensions:
  # - Firefox
  #   - Pwnfox
  #   - Wappalyzer
  # - Brave
  #   - 1Password
  #   - Vimium
  #
  # Vimium custom key mappings:
  #
  # unmapAll
  # map j scrollDown
  # map k scrollUp
  # map f LinkHints.activateMode

  config =
    let
      cfg = config.sprrw.gui.browsers;
    in
    lib.mkIf cfg.enable {
      home.packages = with pkgs; [
        brave
        firefox
        chromium
      ];
    };
}
