{ moduleWithSystem, ... }:

{
  flake.modules.homeManager.browsers = moduleWithSystem (
    { inputs', ... }:
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      programs.brave = {
        enable = true;
        package = inputs'.nixpkgs-master.legacyPackages.brave;
        extensions = [
          { id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa"; } # 1Password
          { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; } # Vimium
        ];
      };

      programs.firefox = {
        enable = true;
        configPath = "${config.xdg.configHome}/mozilla/firefox";
        policies.ExtensionSettings =
          lib.mapAttrs
            (_: slug: {
              installation_mode = "force_installed";
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
            })
            {
              "PwnFox@bi.tk" = "pwnfox";
              "wappalyzer@crunchlabz.com" = "wappalyzer";
            };
      };

      home.packages = [
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
