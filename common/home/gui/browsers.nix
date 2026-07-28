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

      home.sessionVariables.BROWSER = "brave";

      xdg.mimeApps = {
        enable = true;
        defaultApplications = lib.genAttrs [
          "text/html"
          "application/xhtml+xml"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
          "x-scheme-handler/about"
          "x-scheme-handler/unknown"
        ] (_: "brave-browser.desktop");
      };
    };
}
