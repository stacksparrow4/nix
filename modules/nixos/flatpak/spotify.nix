{
  flake.modules.nixos.spotify = {
    services.flatpak = {
      packages = [
        {
          appId = "com.spotify.Client";
          origin = "flathub";
        }
      ];

      overrides = {
        "com.spotify.Client".Context = {
          shared = [ "!ipc" ];
          filesystems = [
            "!xdg-pictures"
            "!xdg-music"
          ];
        };
      };
    };
  };
}
