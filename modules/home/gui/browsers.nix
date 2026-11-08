{ moduleWithSystem, ... }:

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
{
  flake.modules.homeManager.browsers = moduleWithSystem (
    { inputs', ... }:
    { pkgs, lib, ... }:
    {
      home.packages = [
        inputs'.nixpkgs-master.legacyPackages.brave
        pkgs.firefox
        pkgs.chromium
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
          "application/pdf"
        ] (_: "brave-browser.desktop");
      };
    }
  );
}
